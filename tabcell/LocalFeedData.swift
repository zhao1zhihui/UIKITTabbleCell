import Foundation

enum LocalFeedDataStore {
    static var data: Data {
        Data(json.utf8)
    }

    private static let json = """
    {
      "code": 0,
      "message": "ok",
      "data": {
        "items": [
          { "type": "text", "data": { "id": 1, "title": "Quick Loan", "subtitle": "Local text card from bundled data." } },
          { "type": "image", "data": { "id": 2, "title": "Guide", "imageUrl": "local-image-1" } },
          { "type": "action", "data": { "id": 3, "title": "Start Now", "buttonTitle": "Apply" } },
          { "type": "profile", "data": { "id": 4, "name": "Codex Team", "intro": "Delegate-driven profile card from local data source.", "followTitle": "Follow", "messageTitle": "Message" } },
          { "type": "text", "data": { "id": 5, "title": "Repayment Tips", "subtitle": "Page 2 still comes from the same local JSON." } },
          { "type": "image", "data": { "id": 6, "title": "FAQ", "imageUrl": "local-image-2" } },
          { "type": "action", "data": { "id": 7, "title": "Verify Identity", "buttonTitle": "Verify" } },
          { "type": "profile", "data": { "id": 8, "name": "Local Ops", "intro": "Second profile card used to verify delegate expansion.", "followTitle": "Add", "messageTitle": "Ping" } },
          { "type": "text", "data": { "id": 9, "title": "Credit Line", "subtitle": "The third page is still sliced locally." } },
          { "type": "image", "data": { "id": 10, "title": "Security", "imageUrl": "local-image-3" } },
          { "type": "action", "data": { "id": 11, "title": "Continue", "buttonTitle": "Next" } },
          { "type": "profile", "data": { "id": 12, "name": "Support Bot", "intro": "Final local card for pagination and mixed rendering.", "followTitle": "Track", "messageTitle": "Open" } }
        ]
      }
    }
    """
}
