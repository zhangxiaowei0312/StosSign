//
//  AppleAPISession.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation

class AppleAPISession {
    var dsid: String
    var authToken: String
    var anisetteData: AnisetteData 

    init(dsid: String, authToken: String, anisetteData: AnisetteData) {
        self.dsid = dsid
        self.authToken = authToken
        self.anisetteData = anisetteData
    }
}
