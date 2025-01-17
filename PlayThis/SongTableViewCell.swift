//
//  SongTableViewCell.swift
//  PlayThis
//
//  Created by Logan Pratt on 7/13/15.
//  Copyright (c) 2020 Logan Pratt. All rights reserved.
//

import UIKit
import FirebaseDatabase
import Firebase
import Kingfisher

class SongTableViewCell: UITableViewCell {
    
    @IBOutlet weak var albumCover: UIImageView!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var songArtistLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!
    @IBOutlet weak var likesLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    var songObjId = ""
    var groupCode = ""
    let songs = SongsHelper.sharedInstance
    var song: Song!
    var currentLikes: Int = 0
    var ref = Database.database().reference(withPath: "songs")
 
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func setUpCell(song: Song) {
       
        self.song = song
        if let checkedUrl = URL(string: song.coverURL) {
            albumCover.kf.setImage(with: checkedUrl)
        }

        songTitleLabel.text = song.name
        songArtistLabel.text = song.artist
        durationLabel.text = song.duration
        //songObjId = song.id
        
        likesLabel.text = "\(song.likes)"
        currentLikes = song.likes
        //print("\(song.name) has \(song.likes) likes")
        let songIsLiked = songs.likedSongs.map({$0.key}).contains(song.key)
        //print("isLiked \(songs.likedSongs.map({$0.name}))")
        //print(songIsLiked)
        if songIsLiked {
            likeButton.isSelected = true
        } else {
            likeButton.isSelected = false
        }
    }
    
    
    func getDataFromUrl(_ urL:URL, completion: @escaping ((_ data: Data?) -> Void)) {
        URLSession.shared.dataTask(with: urL) { (data, response, error) in
            completion(data)
            }.resume()
    }
    
    func downloadImage(_ url:URL){
        getDataFromUrl(url) { data in
            DispatchQueue.main.async {
                self.albumCover.image = UIImage(data: data!)
            }
        }
    }
 
    
    func updateLikes() {
    }
    
    @IBAction func likeSong(_ sender: AnyObject) {
        //
        if self.likeButton.isSelected {
            self.song.likes = Int(self.likesLabel.text!)! - 1
            self.songs.likedSongs = self.songs.likedSongs.filter() { $0.key != self.song.key }
            self.likeButton.isSelected = false
        } else {
            self.song.likes = Int(self.likesLabel.text!)! + 1
            
            self.songs.likedSongs.append(self.song)
            self.likeButton.isSelected = true
        }
        self.ref.updateChildValues(["\(song.key)/likes": self.song.likes])
    }
 
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
