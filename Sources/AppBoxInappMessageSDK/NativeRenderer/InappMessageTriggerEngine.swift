import Foundation
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

struct InappMessageTriggerRequest: Equatable {
    let trigger: InappMessageTrigger
    let value: String?
    let campaignCode: String?
    let journeyId: Int?
    let nodeCode: String?

    init(
        trigger: InappMessageTrigger,
        value: String? = nil,
        campaignCode: String? = nil,
        journeyId: Int? = nil,
        nodeCode: String? = nil
    ) {
        self.trigger = trigger
        self.value = value
        self.campaignCode = campaignCode
        self.journeyId = journeyId
        self.nodeCode = nodeCode
    }
}

struct InappMessageTriggerMatch: Equatable {
    let campaign: InappMessageCampaign
    let journeyId: Int?
    let nodeCode: String?
}

final class InappMessageTriggerEngine {
    func selectCampaign(
        from campaigns: [InappMessageCampaign],
        request: InappMessageTriggerRequest
    ) -> InappMessageTriggerMatch? {
        selectCampaigns(from: campaigns, request: request).first
    }

    func selectCampaigns(
        from campaigns: [InappMessageCampaign],
        request: InappMessageTriggerRequest
    ) -> [InappMessageTriggerMatch] {
        let sortedCampaigns = stablePrioritySorted(campaigns)
        if let campaignCode = trimmed(request.campaignCode),
           let campaign = sortedCampaigns.first(where: { $0.campaignCode == campaignCode }) {
            return [InappMessageTriggerMatch(
                campaign: campaign,
                journeyId: request.journeyId,
                nodeCode: request.nodeCode
            )]
        }

        return uniqueByCampaignCode(sortedCampaigns.filter { matches($0, request: request) })
            .map {
                InappMessageTriggerMatch(
                    campaign: $0,
                    journeyId: request.journeyId,
                    nodeCode: request.nodeCode
                )
            }
    }

    private func stablePrioritySorted(_ campaigns: [InappMessageCampaign]) -> [InappMessageCampaign] {
        campaigns.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority == rhs.element.priority {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.priority < rhs.element.priority
            }
            .map(\.element)
    }

    private func uniqueByCampaignCode(_ campaigns: [InappMessageCampaign]) -> [InappMessageCampaign] {
        var seen = Set<String>()
        return campaigns.filter { campaign in
            seen.insert(campaign.campaignCode).inserted
        }
    }

    private func matches(_ campaign: InappMessageCampaign, request: InappMessageTriggerRequest) -> Bool {
        guard campaign.trigger == request.trigger else { return false }

        switch request.trigger {
        case .immediate:
            return true
        case .bridge, .journeyPush:
            return triggerValue(campaign.triggerValue, matches: request.value)
        case .urlMatch:
            return urlValue(campaign.triggerValue, matches: request.value)
        }
    }

    private func triggerValue(_ pattern: String?, matches value: String?) -> Bool {
        guard let pattern = trimmed(pattern) else {
            return true
        }
        guard let value = trimmed(value) else {
            return false
        }
        return wildcard(pattern, matches: value) || pattern == value
    }

    private func urlValue(_ pattern: String?, matches value: String?) -> Bool {
        guard let pattern = trimmed(pattern) else {
            return false
        }
        guard let value = trimmed(value) else {
            return false
        }

        if wildcard(pattern, matches: value) || pattern == value {
            return true
        }

        guard !pattern.contains("*") else {
            return false
        }
        return value.localizedCaseInsensitiveContains(pattern)
    }

    private func wildcard(_ pattern: String, matches value: String) -> Bool {
        guard pattern.contains("*") else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
        let regex = "^\(escaped)$"
        return value.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
