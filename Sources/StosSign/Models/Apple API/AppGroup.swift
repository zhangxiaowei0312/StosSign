//
//  AppGroup.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation

public struct AppGroup: Codable {
    var name: String
    var identifier: String
    var groupIdentifier: String
    
    init(name: String, identifier: String, groupIdentifier: String) {
        self.name = name
        self.identifier = identifier
        self.groupIdentifier = groupIdentifier
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case identifier = "applicationGroup"
        case groupIdentifier = "identifier"
    }
}
