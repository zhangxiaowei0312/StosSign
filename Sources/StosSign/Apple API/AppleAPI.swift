//
//  AppleAPI.swift
//  StosSign
//
//  Created by Stossy11 on 18/03/2025.
//

import Foundation

let clientID = "XABBG36SBA"
let QH_Protocol = "QH65B2"
let V1_Protocol = "v1"
let authProtocol = "A1234"

class AppleAPI {
    let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
    let dateFormatter = ISO8601DateFormatter()
    let qhURL = URL(string: "https://developerservices2.apple.com/services/\(QH_Protocol)/")!
    let v1URL = URL(string: "https://developerservices2.apple.com/services/\(V1_Protocol)/")!
    
    func fetchTeamsForAccount(account: Account, session: AppleAPISession, completion: @escaping ([Team]?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("listTeams.action")
        
        sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: nil) { response, error in
            guard let response else {
                completion(nil, error)
                return
            }
            
            var APIerror: AppleAPIError? = nil
            guard let array = response["teams"] as? [[String: Any]] else {
                if error == nil {
                    if let result = response["resultCode"] {
                        let resultCode = (result as? NSNumber)?.intValue ?? 0
                        
                        if resultCode == 0 {
                            APIerror = .unknown
                        } else {
                            let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                            let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                            
                            APIerror = .customError(code: resultCode, message: localizedDescription)
                        }
                    } else {
                        APIerror = .badServerResponse
                    }
                }
                
                completion(nil, APIerror ?? error)
                return
            }
            
            var teams: [Team] = []
            for dictionary in array {
                if let team = Team(account: account, responseDictionary: dictionary) {
                    teams.append(team)
                }
            }
            
            (teams.count == 0) ? completion(nil, AppleAPIError.noTeams) : completion(teams, nil)
        }
    }

    
    func fetchDevicesForTeam(team: Team, session: AppleAPISession, types: DeviceType, completion: @escaping ([Device]?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios").appendingPathComponent("listDevices.action")
        
        self.sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: team) { response, error in
            guard let response else {
                completion(nil, error)
                return
            }
            
            let responseError = error
            var APIerror: AppleAPIError? = nil
            do {
                let data = try JSONSerialization.data(withJSONObject: response["devices"] ?? [])
                let devices = try JSONDecoder().decode([Device].self, from: data)
                var devicesChecked = devices
                devicesChecked.removeAll(where: { types != $0.type })
                completion(devicesChecked, nil)
            } catch {
                if responseError == nil {
                    if let result = response["resultCode"] {
                        let resultCode = (result as? NSNumber)?.intValue ?? 0
                        
                        if resultCode == 0 {
                            APIerror = .unknown
                        } else {
                            let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                            let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                            
                            APIerror = .customError(code: resultCode, message: localizedDescription)
                        }
                    } else {
                        APIerror = .badServerResponse
                    }
                }
                
                completion(nil, APIerror ?? error)
            }
        }
    }
    
    func registerDeviceWithName(name: String, identifier: String, type: DeviceType, team: Team, session: AppleAPISession, completion: @escaping (Device?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios").appendingPathComponent("addDevice.action")
        
        var parameters = [
            "deviceNumber": identifier,
            "name": name
        ]
        
        switch type {
        case .iPad:
            parameters["DTDK_Platform"] = "ios"
        case .AppleTV:
            parameters["DTDK_Platform"] = "tvos"
            parameters["subPlatform"] = "tvOS"
        default: break
        }
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team) { response, error in
            guard let response else {
                completion(nil, error ?? AppleAPIError.unknown)
                return
            }
            
            var APIerror: AppleAPIError? = nil
            
            guard let deviceDictionary = response["device"] as? [String: Any] else {
                if error == nil {
                    if let result = response["resultCode"] {
                        let resultCode = (result as? NSNumber)?.intValue ?? 0
                        
                        if resultCode == 0 {
                            APIerror = .unknown
                        } else {
                            let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                            let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                            
                            APIerror = .customError(code: resultCode, message: localizedDescription)
                        }
                    } else {
                        APIerror = .badServerResponse
                    }
                }
                
                completion(nil, APIerror ?? error ?? AppleAPIError.unknown)
                return
            }
            
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: deviceDictionary, options: [])
                let device = try JSONDecoder().decode(Device.self, from: jsonData)
                completion(device, nil)
                return
            } catch {
                if let result = response["resultCode"] {
                    let resultCode = (result as? NSNumber)?.intValue ?? 0
                    
                    if resultCode == 0 {
                        completion(nil, error)
                        return
                    } else {
                        let errorDescription = response["userString"] as? String ?? response["resultString"] as? String
                        let localizedDescription = String(format: "%@ (%@)", errorDescription ?? "", "\(resultCode)")
                        
                        APIerror = .customError(code: resultCode, message: localizedDescription)
                    }
                } else {
                    APIerror = .badServerResponse
                }
                
                completion(nil, APIerror ?? AppleAPIError.unknown)
                return
            }
        }
    }
    
    func fetchCertificatesForTeam(team: Team, session: AppleAPISession, completion: @escaping ([Certificate]?, Error?) -> Void) {
        let url = v1URL.appendingPathComponent("certificates")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        sendServicesRequest(originalRequest: request, additionalParameters: ["filter[certificateType]": "IOS_DEVELOPMENT"], session: session, team: team) { (responseDictionary, error) in
            guard let data = responseDictionary?["data"] as? [[String: Any]] else {
                completion(nil, error)
                return
            }

            let decoder = JSONDecoder()
            let certificates = data.compactMap { dict -> Certificate? in
                Certificate(responseDictionary: dict)
            }

            completion(certificates, nil)
        }
    }

    func addCertificateWithMachineName(machineName: String, team: Team, session: AppleAPISession, completion: @escaping (Certificate?, Error?) -> Void) {
        guard let certificateRequest = CertificateRequest.generate(), let csr = certificateRequest.csr else {
            completion(nil, AppleAPIError.invalidCertificateRequest)
            return
        }

        let url = qhURL.appendingPathComponent("ios/submitDevelopmentCSR.action")

        sendRequestWithURL(requestURL: url,
            additionalParameters: [
                "csrContent": csr.base64EncodedString(),
                "machineId": UUID().uuidString,
                "machineName": machineName
            ], session: session, team: team) { (responseDictionary, error) in
            guard let certRequestDict = responseDictionary?["certRequest"] as? [String: Any] else {
                completion(nil, error)
                return
            }

            let certificate = Certificate(responseDictionary: certRequestDict)!
            
            certificate.privateKey = certificateRequest.privateKey
            completion(certificate, nil)
        }
    }

    func revokeCertificate(certificate: Certificate, team: Team, session: AppleAPISession, completion: @escaping (Bool, Error?) -> Void) {
        let url = v1URL.appendingPathComponent("certificates").appendingPathComponent(certificate.identifier ?? "")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        sendServicesRequest(originalRequest: request, additionalParameters: nil, session: session, team: team) { (responseDictionary, error) in
            completion(responseDictionary != nil, error)
        }
    }
    
    func fetchAppIDsForTeam(team: Team, session: AppleAPISession, completionHandler: @escaping ([AppID]?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/listAppIds.action")
        
        sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(nil, error)
                return
            }
            
            guard let array = response["appIds"] as? [[String: Any]] else {
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            let appIDs = array.compactMap { AppID(responseDictionary: $0) }
            
            completionHandler(appIDs.isEmpty ? nil : appIDs, nil)
        }
    }
    
    func addAppID(name: String, bundleIdentifier: String, team: Team, session: AppleAPISession, completionHandler: @escaping (AppID?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/addAppId.action")
        
        // Sanitize name similar to ObjC implementation
        var sanitizedName = name.folding(options: .diacriticInsensitive, locale: nil)
        sanitizedName = sanitizedName.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()
        
        if sanitizedName.isEmpty {
            sanitizedName = "App"
        }
        
        let parameters = [
            "identifier": bundleIdentifier,
            "name": sanitizedName
        ]
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(nil, error)
                return
            }
            
            guard let dictionary = response["appId"] as? [String: Any] else {
                // Handle result code errors
                if let resultCode = response["resultCode"] as? Int {
                    switch resultCode {
                    case 35:
                        let error = AppleAPIError.customError(
                            code: resultCode,
                            message: "Invalid App ID Name (\(sanitizedName))"
                        )
                        completionHandler(nil, error)
                    case 9120:
                        completionHandler(nil, AppleAPIError.maximumAppIDLimitReached)
                    case 9401:
                        completionHandler(nil, AppleAPIError.bundleIdentifierUnavailable)
                    case 9412:
                        completionHandler(nil, AppleAPIError.invalidBundleIdentifier)
                    default:
                        completionHandler(nil, error)
                    }
                    return
                }
                
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            guard let appID = AppID(responseDictionary: dictionary) else {
                completionHandler(nil, AppleAPIError.badServerResponse)
                return
            }
            
            completionHandler(appID, nil)
        }
    }
    
    func updateAppID(_ appID: AppID, team: Team, session: AppleAPISession, completionHandler: @escaping (AppID?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/updateAppId.action")
        
        var parameters: [String: Any] = ["appIdId": appID.identifier]
        
        // Add features
        appID.features.forEach { key, value in
            parameters[key] = value
        }
        
        // Handle entitlements based on team type
        var entitlements = appID.entitlements
        
        if team.type == .free {
            entitlements = entitlements.filter { key in
                freeDeveloperCanUseEntitlement(key)
            }
        }
        
        parameters["entitlements"] = entitlements
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters.mapValues { String(describing: $0) }, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(nil, error)
                return
            }
            
            guard let dictionary = response["appId"] as? [String: Any] else {
                // Handle result code errors
                if let resultCode = response["resultCode"] as? Int {
                    switch resultCode {
                    case 35:
                        completionHandler(nil, AppleAPIError.invalidAppIDName)
                    case 9100:
                        completionHandler(nil, AppleAPIError.appIDDoesNotExist)
                    case 9412:
                        completionHandler(nil, AppleAPIError.invalidBundleIdentifier)
                    default:
                        completionHandler(nil, error)
                    }
                    return
                }
                
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            guard let updatedAppID = AppID(responseDictionary: dictionary) else {
                completionHandler(nil, AppleAPIError.badServerResponse)
                return
            }
            
            completionHandler(updatedAppID, nil)
        }
    }
    
    func deleteAppID(_ appID: AppID, team: Team, session: AppleAPISession, completionHandler: @escaping (Bool, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/deleteAppId.action")
        
        let parameters = ["appIdId": appID.identifier]
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(false, error)
                return
            }
            
            // Check result code
            if let resultCode = response["resultCode"] as? Int {
                switch resultCode {
                case 9100:
                    completionHandler(false, AppleAPIError.appIDDoesNotExist)
                case 0:
                    completionHandler(true, nil)
                default:
                    completionHandler(false, error)
                }
                return
            }
            
            completionHandler(false, error ?? AppleAPIError.badServerResponse)
        }
    }
    
    // MARK: - App Groups
    
    func fetchAppGroupsForTeam(team: Team, session: AppleAPISession, completionHandler: @escaping ([AppGroup]?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/listApplicationGroups.action")
        
        sendRequestWithURL(requestURL: url, additionalParameters: nil, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(nil, error)
                return
            }
            
            guard let data = try? JSONSerialization.data(withJSONObject: response["applicationGroupList"] ?? []) else {
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            do {
                let groups = try JSONDecoder().decode([AppGroup].self, from: data)
                completionHandler(groups.isEmpty ? nil : groups, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    func addAppGroup(name: String, groupIdentifier: String, team: Team, session: AppleAPISession, completionHandler: @escaping (AppGroup?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/addApplicationGroup.action")
        
        let parameters = [
            "identifier": groupIdentifier,
            "name": name
        ]
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(nil, error)
                return
            }
            
            guard let dictionary = response["applicationGroup"] as? [String: Any] else {
                if let resultCode = response["resultCode"] as? Int, resultCode == 35 {
                    completionHandler(nil, AppleAPIError.invalidAppGroup)
                    return
                }
                
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            
            
            do {
                let groups = try JSONDecoder().decode(AppGroup.self, from: data)
                completionHandler(groups, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }
    
    func assignAppID(_ appID: AppID, toGroups groups: [AppGroup], team: Team, session: AppleAPISession, completionHandler: @escaping (Bool, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/assignApplicationGroupToAppId.action")
        
        let groupIDs = groups.map { $0.identifier }
        
        let parameters: [String: Any] = [
            "appIdId": appID.identifier,
            "applicationGroups": groupIDs
        ]
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters.mapValues { ($0 as? [String])?.joined(separator: ",") ?? "" }, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(false, error)
                return
            }
            
            if let resultCode = response["resultCode"] as? Int {
                switch resultCode {
                case 9115:
                    completionHandler(false, AppleAPIError.appIDDoesNotExist)
                case 35:
                    completionHandler(false, AppleAPIError.appGroupDoesNotExist)
                case 0:
                    completionHandler(true, nil)
                default:
                    completionHandler(false, error)
                }
                return
            }
            
            completionHandler(false, error ?? AppleAPIError.badServerResponse)
        }
    }
    
    func fetchProvisioningProfileForAppID(appID: AppID, deviceType: DeviceType, team: Team, session: AppleAPISession, completionHandler: @escaping (ProvisioningProfile?, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/downloadTeamProvisioningProfile.action")
        
        var parameters: [String: String] = ["appIdId": appID.identifier]
        
        switch deviceType {
        case .iPhone, .iPad:
            parameters["DTDK_Platform"] = "ios"
        case .AppleTV:
            parameters["DTDK_Platform"] = "tvos"
            parameters["subPlatform"] = "tvOS"
        default:
            break
        }
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(nil, error)
                return
            }
            
            if let resultCode = response["resultCode"] as? Int, resultCode == 8201 {
                completionHandler(nil, AppleAPIError.appIDDoesNotExist)
                return
            }
            
            guard let dictionary = response["provisioningProfile"] else {
                completionHandler(nil, error ?? AppleAPIError.badServerResponse)
                return
            }
            
            do {
                let data = try JSONSerialization.data(withJSONObject: dictionary)
                let decoder = JSONDecoder()
                let provisioningProfile = try decoder.decode(ProvisioningProfile.self, from: data)
                completionHandler(provisioningProfile, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    
    func deleteProvisioningProfile(_ provisioningProfile: ProvisioningProfile, team: Team, session: AppleAPISession, completionHandler: @escaping (Bool, Error?) -> Void) {
        let url = qhURL.appendingPathComponent("ios/deleteProvisioningProfile.action")
        
        let parameters = [
            "provisioningProfileId": provisioningProfile.identifier,
            "teamId": team.identifier
        ]
        
        sendRequestWithURL(requestURL: url, additionalParameters: parameters, session: session, team: team) { response, error in
            guard let response else {
                completionHandler(false, error)
                return
            }

            if let resultCode = response["resultCode"] as? Int {
                switch resultCode {
                case 35:
                    completionHandler(false, AppleAPIError.invalidProvisioningProfileIdentifier)
                case 8101:
                    completionHandler(false, AppleAPIError.provisioningProfileDoesNotExist)
                case 0:
                    completionHandler(true, nil)
                default:
                    completionHandler(false, error)
                }
                return
            }
            
            completionHandler(false, error ?? AppleAPIError.badServerResponse)
        }
    }
    
    
    func sendServicesRequest(originalRequest: URLRequest, additionalParameters: [String: String]? = nil, session: AppleAPISession,team: Team, completion: @escaping ([String: Any]?, Error?) -> Void) {
        var request = originalRequest
        
        var queryItems = [URLQueryItem(name: "teamId", value: team.identifier)]
        
        additionalParameters?.forEach { key, value in
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        var components = URLComponents()
        components.queryItems = queryItems
        let queryString = components.query ?? ""
        
        do {
            let bodyData = try JSONSerialization.data(
                withJSONObject: ["urlEncodedQueryParams": queryString],
                options: []
            )
            request.httpBody = bodyData
        } catch {
            let nsError = NSError(
                domain: "AppleAPIErrorDomain",
                code: -1,
                userInfo: [NSUnderlyingErrorKey: error]
            )
            completion(nil, nsError)
            return
        }
        
        let originalHTTPMethod = request.httpMethod
        request.httpMethod = "POST"
        
        let httpHeaders: [String: String] = [
            "Content-Type": "application/vnd.api+json",
            "User-Agent": "Xcode",
            "Accept": "application/vnd.api+json",
            "Accept-Language": "en-us",
            "X-Apple-App-Info": "com.apple.gs.xcode.auth",
            "X-Xcode-Version": "11.2 (11B41)",
            "X-HTTP-Method-Override": originalHTTPMethod ?? "",
            "X-Apple-I-Identity-Id": session.dsid,
            "X-Apple-GS-Token": session.authToken,
            "X-Apple-I-MD-M": session.anisetteData.machineID,
            "X-Apple-I-MD": session.anisetteData.oneTimePassword,
            "X-Apple-I-MD-LU": session.anisetteData.localUserID,
            "X-Apple-I-MD-RINFO": String(session.anisetteData.routingInfo),
            "X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
            "X-MMe-Client-Info": session.anisetteData.deviceDescription,
            "X-Apple-I-Client-Time": dateFormatter.string(from: session.anisetteData.date),
            "X-Apple-Locale": session.anisetteData.locale.identifier,
            "X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation() ?? ""
        ]
        
        httpHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                completion(nil, error)
                return
            }
            
            guard !data.isEmpty else {
                completion([:], nil)
                return
            }
            
            do {
                let responseDictionary = try JSONSerialization.jsonObject(
                    with: data,
                    options: []
                ) as? [String: Any]
                
                completion(responseDictionary, nil)
            } catch {
                completion(nil, AppleAPIError.badServerResponse)
            }
        }
        
        task.resume()
    }
    

    func sendRequestWithURL(requestURL: URL, additionalParameters: [String: String]?, session: AppleAPISession, team: Team?, completion: @escaping ([String: Any]?, Error?) -> Void) {
        var parameters: [String: String] = [
            "clientId": clientID,
            "protocolVersion": QH_Protocol, // v1 Protocol is newer
            "requestId": UUID().uuidString.uppercased()
        ]
        
        if let team = team {
            parameters["teamId"] = team.identifier
        }
        
        additionalParameters?.forEach { key, value in
            parameters[key] = value
        }
        
        do {
            let bodyData = try PropertyListSerialization.data(fromPropertyList: parameters, format: .xml, options: 0)
            
            var urlString = requestURL.absoluteString
            urlString.append("?clientId=\(clientID)")
            guard let url = URL(string: urlString) else {
                let error = AppleAPIError.invalidParameters
                completion(nil, error)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = bodyData
            
            let httpHeaders: [String: String] = [
                "Content-Type": "text/x-xml-plist",
                "User-Agent": "Xcode",
                "Accept": "text/x-xml-plist",
                "Accept-Language": "en-us",
                "X-Apple-App-Info": "com.apple.gs.xcode.auth",
                "X-Xcode-Version": "11.2 (11B41)",
                "X-Apple-I-Identity-Id": session.dsid,
                "X-Apple-GS-Token": session.authToken,
                "X-Apple-I-MD-M": session.anisetteData.machineID,
                "X-Apple-I-MD": session.anisetteData.oneTimePassword,
                "X-Apple-I-MD-LU": session.anisetteData.localUserID,
                "X-Apple-I-MD-RINFO": "\(session.anisetteData.routingInfo)",
                "X-Mme-Device-Id": session.anisetteData.deviceUniqueIdentifier,
                "X-MMe-Client-Info": session.anisetteData.deviceDescription,
                "X-Apple-I-Client-Time": dateFormatter.string(from: session.anisetteData.date),
                "X-Apple-Locale": session.anisetteData.locale.identifier,
                "X-Apple-I-Locale": session.anisetteData.locale.identifier,
                "X-Apple-I-TimeZone": session.anisetteData.timeZone.abbreviation() ?? "GMT"
            ]
            
            for (key, value) in httpHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            self.session.dataTask(with: request) { data, response, error in
                guard let data = data else {
                    completion(nil, error)
                    return
                }
                
                do {
                    if let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        completion(responseDictionary, nil)
                    } else {
                        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: [NSUnderlyingErrorKey: error ?? AppleAPIError.badServerResponse ])
                        completion(nil, error)
                    }
                } catch let parseError {
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: [NSUnderlyingErrorKey: parseError])
                    completion(nil, error)
                }
            }.resume()
        } catch let serializationError {
            let error = AppleAPIError.invalidParameters
            completion(nil, error)
        }
    }

}


public enum SignError: Int, Error {
    case unknown
    case invalidApp
    case missingAppBundle
    case missingInfoPlist
    case missingProvisioningProfile
}

public enum AppleAPIError: Error {
    case unknown
    case invalidParameters
    case badServerResponse
    case incorrectCredentials
    case appSpecificPasswordRequired
    case noTeams
    case invalidDeviceID
    case deviceAlreadyRegistered
    case invalidCertificateRequest
    case certificateDoesNotExist
    case invalidAppIDName
    case invalidBundleIdentifier
    case bundleIdentifierUnavailable
    case appIDDoesNotExist
    case maximumAppIDLimitReached
    case invalidAppGroup
    case appGroupDoesNotExist
    case invalidProvisioningProfileIdentifier
    case provisioningProfileDoesNotExist
    case requiresTwoFactorAuthentication
    case incorrectVerificationCode
    case authenticationHandshakeFailed
    case invalidAnisetteData
    case customError(code: Int, message: String)
}
