//
//  GroupModels.swift
//  Stepmates Auth
//
//  Created by Диана on 09/05/2026.
//

struct MapGroupDTO: Decodable {
    let id: Int
    let name: String
    let avatarUrl: String?
    let membersCount: Int
    let myPlace: Int?
    let goalSteps: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
        case membersCount = "members_count"
        case myPlace = "my_place"
        case goalSteps = "goal_steps"
    }
}

struct MapRankingDTO: Decodable {
    let myPlace: Int?
    let total: Int
    let steps: Int

    enum CodingKeys: String, CodingKey {
        case myPlace = "my_place"
        case total
        case steps
    }
}
