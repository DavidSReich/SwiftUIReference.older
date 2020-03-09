//
//  NetworkService.swift
//  SwiftUIReference
//
//  Created by David S Reich on 6/3/20.
//  Copyright © 2020 Stellar Software Pty Ltd. All rights reserved.
//

import Foundation
import RxSwift

//protocol HandleReferenceErrorProtocol {
//    func handleReferenceError(referenceError: ReferenceError)
//}
//
//protocol DataManagerProtocol: ResultStackProtocol {
//    var imageModels: [ImageDataModelProtocolWrapper] { get }
//    var tagsArray: [String] { get }
//    func clearDataSource()
//    func populateDataSource(urlString: String,
//                            useRxSwift: Bool,
//                            networkingType: UserSettings.NetworkingType,
//                            completion: @escaping (_ referenceError: ReferenceError?) -> Void)
//}
//
//protocol ResultStackProtocol {
//    func pushResults(tagsString: String)
//    func popResults()
//    func popToTop()
//    var lastTagsString: String { get }
//    var tagString: String { get }
//}

struct NetworkService {
//    private var resultsStack = ResultsStack()
    private let disposeBag = DisposeBag()
//    private var imageDataSource: ImageDataSourceProtocol = ImageDataSource(with: [])
//    private var currentTagString = ""

    func getJSONData(urlString: String,
                     useRxSwift: Bool,
                     networkingType: UserSettings.NetworkingType,
                     completion: @escaping (DataResult) -> Void) {

        if useRxSwift {
            getJSONWithRxSwift(urlString: urlString, networkingType: networkingType, not200Handler: self, completion: completion)
        } else {
            getJSONWithoutRxSwift(urlString: urlString, networkingType: networkingType, not200Handler: self, completion: completion)
        }
    }

    private func getJSONWithoutRxSwift(urlString: String,
                                       networkingType: UserSettings.NetworkingType,
                                       not200Handler: HTTPURLResponseNot200? = nil,
                                       completion: @escaping (DataResult) -> Void) {
        let referenceError = JSONNetworkService.getJSON(urlString: urlString,
                                                        networkingType: networkingType,
                                                        not200Handler: not200Handler,
                                                        completion: completion)

        if let referenceError = referenceError {
            completion(.failure(ReferenceError.noFetchJSON(referenceError: referenceError)))
        }
    }

    private func getJSONWithRxSwift(urlString: String,
                                    networkingType: UserSettings.NetworkingType,
                                    not200Handler: HTTPURLResponseNot200? = nil,
                                    completion: @escaping (DataResult) -> Void) {
        guard let jsonObservable = JSONNetworkService.getJSONObservable(urlString: urlString,
                                                                        networkingType: networkingType,
                                                                        not200Handler: not200Handler) else {
                                                                            completion(.failure(.badURL))
            return
        }

        jsonObservable.subscribe(onNext: { result in
            completion(result)
        },
        onError: { error in
            print("error: \(error)")
            completion(.failure(error as? ReferenceError ?? .dataTask(error: error)))
        }).disposed(by: disposeBag)
    }

    /*
    private func handleData(data: Data, completion: @escaping (_ referenceError: ReferenceError?) -> Void) {
        self.prettyPrintData(data: data)

        let result: Result<GiphyModel, ReferenceError> = data.decodeData()
        switch result {
        case .success(let giphyModel):
            let imageDataModels = ImageDataModel.getWrappedImageModels(from: giphyModel)
            //print("imagemodels: \(imageDataModels)")
            //print("imagemodels.count: \(imageDataModels.count)")

            self.imageDataSource = ImageDataSource(with: imageDataModels)
            completion(nil)
        case .failure(let referenceError):
            self.imageDataSource = ImageDataSource(with: [ImageDataModelProtocolWrapper]())
            completion(referenceError)
        }
    }
     */

    // handy for debugging
    private func prettyPrintData(data: Data) {
        if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) {
            if let prettyPrintedData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                if let detailString = String(data: prettyPrintedData, encoding: .utf8) {
                    print("json:\n\(detailString)")
                }
            }
        }
    }
}

//this mainly just hides the imageDataSource
//extension DataManager: DataManagerProtocol {
//    internal var imageModels: [ImageDataModelProtocolWrapper] {
//        return imageDataSource.images
//    }
//
//    internal var tagsArray: [String] {
//        return imageDataSource.tagsArray
//    }
//
//    func clearDataSource() {
//        imageDataSource.clear()
//    }
//
//    func populateDataSource(urlString: String,
//                            useRxSwift: Bool,
//                            networkingType: UserSettings.NetworkingType,
//                            completion: @escaping (_ referenceError: ReferenceError?) -> Void) {
//        fillDataSource(urlString: urlString, useRxSwift: useRxSwift, networkingType: networkingType, completion: completion)
//    }
//}
//
//extension DataManager: ResultStackProtocol {
//    func pushResults(tagsString: String) {
//        resultsStack.pushResults(tagsString: tagsString, images: imageDataSource.images)
//    }
//
//    func popResults() {
//        if let results = resultsStack.popResults() {
//            currentTagString = results.tagsString
//            imageDataSource = ImageDataSource(with: results.images)
//        }
//    }
//
//    func popToTop() {
//        if let results = resultsStack.popToTop() {
//            currentTagString = results.tagsString
//            imageDataSource = ImageDataSource(with: results.images)
//        }
//    }
//
//    var lastTagsString: String {
//        return resultsStack.getLast()?.tagsString ?? ""
//    }
//
//    var tagString: String {
//        return currentTagString
//    }
//}

extension NetworkService: HTTPURLResponseNot200 {
    // handle non-200 response codes -- in case there's more info available
    // returns true if it "consumes" the case
    func responseHandler(urlResponse: HTTPURLResponse,
                         data: Data?,
                         completion: @escaping (DataResult) -> Void) -> Bool {
        if [401, 403].contains(urlResponse.statusCode), let data = data {
            let result: Result<MessageModel, ReferenceError> = data.decodeData()

            if case .success(let messageModel) = result {
                //print("403 error: \(messageModel.message)")
                var message = messageModel.message
                if urlResponse.statusCode == 403 {
                    message = "API Key might be incorrect.  Go to Settings to check it."
                }
                completion(.failure(.apiNotHappy(message: message)))
                return true
            }
        }

        return false
    }
}