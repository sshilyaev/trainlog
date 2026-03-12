//
//  FirestoreVisitService.swift
//  TrainLog
//

import Foundation
import FirebaseFirestore

final class FirestoreVisitService: VisitServiceProtocol {
    private let visits = Firestore.firestore().collection("visits")
    private let memberships = Firestore.firestore().collection("memberships")

    func fetchVisits(coachProfileId: String, traineeProfileId: String) async throws -> [Visit] {
        let snapshot = try await visits
            .whereField("coachProfileId", isEqualTo: coachProfileId)
            .whereField("traineeProfileId", isEqualTo: traineeProfileId)
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            parseVisit(id: doc.documentID, data: doc.data())
        }
    }

    func createVisit(coachProfileId: String, traineeProfileId: String, date: Date) async throws -> Visit {
        let createdAt = Date()
        let data: [String: Any] = [
            "coachProfileId": coachProfileId,
            "traineeProfileId": traineeProfileId,
            "createdAt": Timestamp(date: createdAt),
            "date": Timestamp(date: date),
            "status": VisitStatus.planned.rawValue,
            "paymentStatus": VisitPaymentStatus.unpaid.rawValue
        ]
        let ref = try await visits.addDocument(data: data)
        return Visit(
            id: ref.documentID,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: createdAt,
            date: date,
            status: .planned,
            paymentStatus: .unpaid,
            membershipId: nil
        )
    }

    func updateVisit(_ visit: Visit) async throws {
        var data: [String: Any] = [
            "coachProfileId": visit.coachProfileId,
            "traineeProfileId": visit.traineeProfileId,
            "createdAt": Timestamp(date: visit.createdAt),
            "date": Timestamp(date: visit.date),
            "status": visit.status.rawValue,
            "paymentStatus": visit.paymentStatus.rawValue
        ]
        if let mId = visit.membershipId { data["membershipId"] = mId }
        if let code = visit.membershipDisplayCode { data["membershipDisplayCode"] = code }
        try await visits.document(visit.id).setData(data)
    }

    func markVisitDone(_ visit: Visit) async throws {
        let db = Firestore.firestore()
        let visitRef = visits.document(visit.id)

        // Транзакции Firestore не поддерживают query.getDocuments внутри транзакции,
        // поэтому выбираем кандидата заранее и уже его обновляем атомарно.
        let snapshot = try await memberships
            .whereField("coachProfileId", isEqualTo: visit.coachProfileId)
            .whereField("traineeProfileId", isEqualTo: visit.traineeProfileId)
            .whereField("status", isEqualTo: MembershipStatus.active.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 5)
            .getDocuments()

        let candidates: [Membership] = snapshot.documents.compactMap { doc in
            parseMembership(id: doc.documentID, data: doc.data())
        }
        let chosen = candidates.first(where: { $0.remainingSessions > 0 })
        let chosenRef = chosen.map { memberships.document($0.id) }

        if let chosenRef, let chosen {
            _ = try await db.runTransaction { transaction, _ in
                let visitSnap: DocumentSnapshot
                let membershipSnap: DocumentSnapshot
                do {
                    visitSnap = try transaction.getDocument(visitRef)
                    membershipSnap = try transaction.getDocument(chosenRef)
                } catch {
                    return nil
                }
                guard let visitData = visitSnap.data(),
                      let currentVisit = self.parseVisit(id: visitSnap.documentID, data: visitData) else { return nil }
                if currentVisit.status == .done { return nil }

                guard let membershipData = membershipSnap.data(),
                      var m = self.parseMembership(id: membershipSnap.documentID, data: membershipData) else {
                    transaction.updateData([
                        "status": VisitStatus.done.rawValue,
                        "paymentStatus": VisitPaymentStatus.debt.rawValue
                    ], forDocument: visitRef)
                    return nil
                }

                if m.status == .active, m.remainingSessions > 0 {
                    m.usedSessions += 1
                    if m.usedSessions >= m.totalSessions {
                        m.status = .finished
                    }

                    var mData: [String: Any] = [
                        "coachProfileId": m.coachProfileId,
                        "traineeProfileId": m.traineeProfileId,
                        "createdAt": Timestamp(date: m.createdAt),
                        "totalSessions": max(0, m.totalSessions),
                        "usedSessions": max(0, m.usedSessions),
                        "status": m.status.rawValue
                    ]
                    if let p = m.priceRub { mData["priceRub"] = p }
                    if let code = m.displayCode { mData["displayCode"] = code }
                    transaction.setData(mData, forDocument: chosenRef)

                    var visitUpdate: [String: Any] = [
                        "status": VisitStatus.done.rawValue,
                        "paymentStatus": VisitPaymentStatus.paid.rawValue,
                        "membershipId": chosen.id
                    ]
                    if let code = chosen.displayCode { visitUpdate["membershipDisplayCode"] = code }
                    transaction.updateData(visitUpdate, forDocument: visitRef)
                } else {
                    transaction.updateData([
                        "status": VisitStatus.done.rawValue,
                        "paymentStatus": VisitPaymentStatus.debt.rawValue
                    ], forDocument: visitRef)
                }
                return nil
            }
        } else {
            // Абонементов нет — просто отмечаем визит как долг.
            try await visits.document(visit.id).updateData([
                "status": VisitStatus.done.rawValue,
                "paymentStatus": VisitPaymentStatus.debt.rawValue
            ])
        }
    }

    func markVisitDoneWithMembership(_ visit: Visit, membershipId: String) async throws {
        let db = Firestore.firestore()
        let visitRef = visits.document(visit.id)
        let chosenRef = memberships.document(membershipId)

        let membershipSnap = try await chosenRef.getDocument()
        guard let membershipData = membershipSnap.data(),
              var m = parseMembership(id: membershipSnap.documentID, data: membershipData),
              m.coachProfileId == visit.coachProfileId, m.traineeProfileId == visit.traineeProfileId,
              m.status == .active, m.remainingSessions > 0 else {
            try await visits.document(visit.id).updateData([
                "status": VisitStatus.done.rawValue,
                "paymentStatus": VisitPaymentStatus.debt.rawValue
            ])
            return
        }

        m.usedSessions += 1
        if m.usedSessions >= m.totalSessions {
            m.status = .finished
        }
        var mData: [String: Any] = [
            "coachProfileId": m.coachProfileId,
            "traineeProfileId": m.traineeProfileId,
            "createdAt": Timestamp(date: m.createdAt),
            "totalSessions": max(0, m.totalSessions),
            "usedSessions": max(0, m.usedSessions),
            "status": m.status.rawValue
        ]
        if let p = m.priceRub { mData["priceRub"] = p }
        if let code = m.displayCode { mData["displayCode"] = code }

        _ = try await db.runTransaction { transaction, _ in
            let visitSnap: DocumentSnapshot
            do {
                visitSnap = try transaction.getDocument(visitRef)
            } catch {
                return nil
            }
            guard let visitData = visitSnap.data(),
                  let currentVisit = self.parseVisit(id: visitSnap.documentID, data: visitData) else { return nil }
            if currentVisit.status == .done { return nil }

            transaction.setData(mData, forDocument: chosenRef)
            var visitUpdate: [String: Any] = [
                "status": VisitStatus.done.rawValue,
                "paymentStatus": VisitPaymentStatus.paid.rawValue,
                "membershipId": m.id
            ]
            if let code = m.displayCode { visitUpdate["membershipDisplayCode"] = code }
            transaction.updateData(visitUpdate, forDocument: visitRef)
            return nil
        }
    }

    func markVisitPaid(_ visit: Visit) async throws {
        try await visits.document(visit.id).updateData([
            "paymentStatus": VisitPaymentStatus.paid.rawValue
        ])
    }

    func markVisitPaidWithMembership(_ visit: Visit, membershipId: String) async throws {
        guard visit.paymentStatus == .debt else { return }
        let db = Firestore.firestore()
        let visitRef = visits.document(visit.id)
        let chosenRef = memberships.document(membershipId)

        let membershipSnap = try await chosenRef.getDocument()
        guard let membershipData = membershipSnap.data(),
              let m = parseMembership(id: membershipSnap.documentID, data: membershipData),
              m.status == .active, m.remainingSessions > 0,
              m.coachProfileId == visit.coachProfileId, m.traineeProfileId == visit.traineeProfileId else { return }

        _ = try await db.runTransaction { transaction, _ in
            let membershipSnap2: DocumentSnapshot
            do {
                membershipSnap2 = try transaction.getDocument(chosenRef)
            } catch {
                return nil
            }
            guard let data = membershipSnap2.data(),
                  var member = self.parseMembership(id: membershipSnap2.documentID, data: data),
                  member.status == .active, member.remainingSessions > 0 else { return nil }

            member.usedSessions += 1
            if member.usedSessions >= member.totalSessions {
                member.status = .finished
            }
            var mData: [String: Any] = [
                "coachProfileId": member.coachProfileId,
                "traineeProfileId": member.traineeProfileId,
                "createdAt": Timestamp(date: member.createdAt),
                "totalSessions": max(0, member.totalSessions),
                "usedSessions": max(0, member.usedSessions),
                "status": member.status.rawValue
            ]
            if let p = member.priceRub { mData["priceRub"] = p }
            if let code = member.displayCode { mData["displayCode"] = code }
            transaction.setData(mData, forDocument: chosenRef)

            var visitUpdate: [String: Any] = [
                "paymentStatus": VisitPaymentStatus.paid.rawValue,
                "membershipId": member.id
            ]
            if let code = member.displayCode { visitUpdate["membershipDisplayCode"] = code }
            transaction.updateData(visitUpdate, forDocument: visitRef)
            return nil
        }
    }

    func cancelVisit(_ visit: Visit) async throws {
        let db = Firestore.firestore()
        let visitRef = visits.document(visit.id)

        _ = try await db.runTransaction { transaction, _ in
            let visitSnap: DocumentSnapshot
            do {
                visitSnap = try transaction.getDocument(visitRef)
            } catch {
                return nil
            }
            guard let visitData = visitSnap.data(),
                  let current = self.parseVisit(id: visitSnap.documentID, data: visitData) else { return nil }

            if current.status == .cancelled { return nil }

            // Если визит был списан с абонемента — вернуть занятие обратно.
            if current.status == .done, current.paymentStatus == .paid, let mId = current.membershipId, !mId.isEmpty {
                let mRef = self.memberships.document(mId)
                let mSnap: DocumentSnapshot
                do {
                    mSnap = try transaction.getDocument(mRef)
                } catch {
                    // Даже если абонемент не читается — всё равно отменяем визит, не создавая долг.
                    transaction.updateData([
                        "status": VisitStatus.cancelled.rawValue,
                        "paymentStatus": VisitPaymentStatus.unpaid.rawValue,
                        "membershipId": FieldValue.delete(),
                        "membershipDisplayCode": FieldValue.delete()
                    ], forDocument: visitRef)
                    return nil
                }

                if let mData = mSnap.data(), var m = self.parseMembership(id: mSnap.documentID, data: mData) {
                    m.usedSessions = max(0, m.usedSessions - 1)
                    if m.status == .finished, m.remainingSessions > 0 {
                        m.status = .active
                    }
                    var updatedM: [String: Any] = [
                        "coachProfileId": m.coachProfileId,
                        "traineeProfileId": m.traineeProfileId,
                        "createdAt": Timestamp(date: m.createdAt),
                        "totalSessions": max(0, m.totalSessions),
                        "usedSessions": max(0, m.usedSessions),
                        "status": m.status.rawValue
                    ]
                    if let p = m.priceRub { updatedM["priceRub"] = p }
                    if let code = m.displayCode { updatedM["displayCode"] = code }
                    transaction.setData(updatedM, forDocument: mRef)
                }
            }

            transaction.updateData([
                "status": VisitStatus.cancelled.rawValue,
                "paymentStatus": VisitPaymentStatus.unpaid.rawValue,
                "membershipId": FieldValue.delete(),
                "membershipDisplayCode": FieldValue.delete()
            ], forDocument: visitRef)
            return nil
        }
    }

    private func parseVisit(id: String, data: [String: Any]) -> Visit? {
        guard let coachProfileId = data["coachProfileId"] as? String,
              let traineeProfileId = data["traineeProfileId"] as? String else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let date = (data["date"] as? Timestamp)?.dateValue() ?? createdAt
        let statusRaw = data["status"] as? String
        let status = statusRaw.flatMap { VisitStatus(rawValue: $0) } ?? .planned
        let payRaw = data["paymentStatus"] as? String
        let paymentStatus = payRaw.flatMap { VisitPaymentStatus(rawValue: $0) } ?? .unpaid
        let membershipId = data["membershipId"] as? String
        let membershipDisplayCode = data["membershipDisplayCode"] as? String

        return Visit(
            id: id,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: createdAt,
            date: date,
            status: status,
            paymentStatus: paymentStatus,
            membershipId: membershipId,
            membershipDisplayCode: membershipDisplayCode
        )
    }

    private func parseMembership(id: String, data: [String: Any]) -> Membership? {
        guard let coachProfileId = data["coachProfileId"] as? String,
              let traineeProfileId = data["traineeProfileId"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let totalSessions = (data["totalSessions"] as? NSNumber)?.intValue ?? 0
        let usedSessions = (data["usedSessions"] as? NSNumber)?.intValue ?? 0
        let priceRub = (data["priceRub"] as? NSNumber)?.intValue
        let statusRaw = data["status"] as? String
        let status = statusRaw.flatMap { MembershipStatus(rawValue: $0) } ?? .active
        let displayCode = data["displayCode"] as? String
        return Membership(
            id: id,
            coachProfileId: coachProfileId,
            traineeProfileId: traineeProfileId,
            createdAt: createdAt,
            totalSessions: totalSessions,
            usedSessions: usedSessions,
            priceRub: priceRub,
            status: status,
            displayCode: displayCode
        )
    }
}

