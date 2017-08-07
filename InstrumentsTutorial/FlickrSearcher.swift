//
//  FlickrSearcher.swift
//  flickrSearch
//
//  Created by Richard Turton on 31/07/2014.
//  Copyright (c) 2014 Razeware. All rights reserved.
//

import Foundation
import UIKit

let apiKey = "xxxx"

struct FlickrSearchResults {
    let searchTerm: String
    let searchResults: [FlickrPhoto]
}

enum FlickrError: Error {
    case jsonError(value: String)
    case apiError(value: String)
    case unknown
}

class FlickrPhoto: Equatable {
    let photoID: String
    let title: String
    fileprivate let farm: Int
    fileprivate let server: String
    fileprivate let secret: String
  
    typealias ImageLoadCompletion = (_ image: UIImage?, _ error: FlickrError?) -> Void
  
    init (photoID: String, title: String, farm: Int, server: String, secret: String) {
        self.photoID = photoID
        self.title = title
        self.farm = farm
        self.server = server
        self.secret = secret
    }
  
    func flickrImageURL(size: String = "m") -> URL {
        return URL(string: "http://farm\(farm).staticflickr.com/\(server)/\(photoID)_\(secret)_\(size).jpg")!
    }
  
    func loadThumbnail(_ completion: @escaping ImageLoadCompletion) {
        loadImageFromURL(URL: flickrImageURL(size: "m")) { image, error in
            completion(image, error)
        }
    }

    func loadLargeImage(_ completion: @escaping ImageLoadCompletion) {
        loadImageFromURL(URL: flickrImageURL(size: "b"), completion)
    }
  
    func loadImageFromURL(URL: URL, _ completion: @escaping ImageLoadCompletion) {
        let loadRequest = URLRequest(url: URL)
        NSURLConnection.sendAsynchronousRequest(loadRequest, queue: OperationQueue.main) { response, data, error in
            if let error = error {
                completion(nil, FlickrError.apiError(value: error.localizedDescription))
                return
            }
        
            if let data = data {
                completion(UIImage(data: data), nil)
                return
            }
        
            completion(nil, FlickrError.unknown)
        }
    }
}


extension FlickrPhoto {
    var isFavourite: Bool {
        get {
            return UserDefaults.standard.bool(forKey: photoID)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: photoID)
        }
    }
}

func == (lhs: FlickrPhoto, rhs: FlickrPhoto) -> Bool {
    return lhs.photoID == rhs.photoID
}

class Flickr {
  
    let processingQueue = OperationQueue()
  
    func searchFlickrForTerm(_ searchTerm: String, completion: @escaping (_ results: FlickrSearchResults?, _ error: FlickrError?) -> Void){
    
        let searchURL = flickrSearchURLForSearchTerm(searchTerm)
        let searchRequest = URLRequest(url: searchURL)
    
        NSURLConnection.sendAsynchronousRequest(searchRequest, queue: processingQueue) { response, data, error in
            if let error = error {
                completion(nil, FlickrError.apiError(value: error.localizedDescription))
                return
            }
            
            guard let resultObj = try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions()), let resultsDictionary = resultObj as? Dictionary<String, Any> else {
                completion(nil, FlickrError.jsonError(value: "json parse error"))
                return
            }
      
            switch (resultsDictionary["stat"] as! String) {
            case "ok":
                print("Results processed OK")
            case "fail":
                completion(nil, FlickrError.apiError(value: "request failed"))
                return
            default:
                completion(nil, FlickrError.apiError(value: "unknown api response"))
                return
            }
      
            let photosContainer = resultsDictionary["photos"] as! NSDictionary
            let photosReceived = photosContainer["photo"] as! [NSDictionary]
          
            let flickrPhotos: [FlickrPhoto] = photosReceived.map { photoDictionary in
            
                let photoID = photoDictionary["id"] as? String ?? ""
                let title = photoDictionary["title"] as? String ?? ""
                let farm = photoDictionary["farm"] as? Int ?? 0
                let server = photoDictionary["server"] as? String ?? ""
                let secret = photoDictionary["secret"] as? String ?? ""
            
                let flickrPhoto = FlickrPhoto(photoID: photoID, title: title, farm: farm, server: server, secret: secret)
            
                return flickrPhoto
            }
      
            DispatchQueue.main.async {
                completion(FlickrSearchResults(searchTerm: searchTerm, searchResults: flickrPhotos), nil)
            }
        }
    }
  
    fileprivate func flickrSearchURLForSearchTerm(_ searchTerm: String) -> URL {
        let urlString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&text=\(searchTerm)&per_page=30&format=json&nojsoncallback=1"
        return URL(string: urlString)!
    }
}
