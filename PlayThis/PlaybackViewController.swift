//
//  PlaybackViewController.swift
//  PlayThis
//
//  Created by Logan Pratt on 7/14/15.
//  Copyright (c) 2020 Logan Pratt. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MediaPlayer
import XCDYouTubeKit
import NVActivityIndicatorView
import MarqueeLabel

class PlaybackViewController: UIViewController {
    
    @IBOutlet weak var songImageView: UIImageView!
    @IBOutlet weak var songLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var endTimeLabel: UILabel! {
        didSet{
            if endTimeLabel.text != "0:00" {
                timeSlider?.isEnabled = true
            }
        }
    }
    @IBOutlet var loadingView: NVActivityIndicatorView!
    //    let ytPlayer = YTPlayerView()
    
    @objc static let sharedInstance = PlaybackViewController()
    
    let songs = SongsHelper.sharedInstance.songs
    let playbackInstance = PlaybackHelper.sharedInstance
    var player = PlaybackHelper.sharedInstance.player
    var playerItems: [AVPlayerItem] = []
    var song = SongsHelper.sharedInstance.songs[0]
    var endOfPlaylist = false
    var songId = ""
    var imageUrl = ""
    var songTitle = ""
    var songArtist = ""
    var albumCover = UIImage()
    var firstIndex = 0
    var currentSongIndex = 0 {
        didSet{
            print("Current index: \(currentSongIndex)")
            if currentSongIndex < songs.count {
                song = songs[currentSongIndex]
                print("SONG \(song.name)")
                
            } else {
                print("CS \(currentSongIndex)")
                currentSongIndex -= 1
            }
            PlaybackHelper.sharedInstance.currentSongIndex = self.currentSongIndex
        }
    }
    var loadedItems = 0
    var isPlaying = true
    
    var playlist: [String]!
    
    var periodicTimeObserver: AnyObject?
    var timePlayed = 0
    var duration: Int!
    
    var timer: Timer!
    var playerStartedTimer: Timer!
    var waitTimer: Timer!
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navBar.shadowImage = UIImage()
        
//        webView.allowsInlineMediaPlayback = true
//        webView.mediaPlaybackRequiresUserAction = false
        
        //        ytPlayer.delegate = self
        player.pause()
        player.removeAllItems()
        playlist = []
        createPlaylist(song.id)
        print("song name: \(song.name)")
        self.play()
        firstIndex=currentSongIndex
        setUpView()
    }
    
    @objc func setUpView() {
        currentTimeLabel.text = "0:00"
        endTimeLabel.text = "0:00"
        timeSlider.value = 0
        timeSlider.isEnabled = false
        
        songLabel.text = song.name
        artistLabel.text = song.artist
        
        playButton.isHidden = true
        pauseButton.isHidden = true
        pauseButton.isEnabled = false
        pauseButton.isHidden = true
        loadingView.startAnimating()
        
        if let checkedUrl = URL(string: song.coverURL) {
            songImageView.kf.setImage(with: checkedUrl)
        }
 
        previousButton.isEnabled = false
        nextButton.isEnabled = false
        
        playerStartedTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(PlaybackViewController.checkIfPlayerReady), userInfo: nil, repeats: true)
    }
    
    func toggleSkipPrevious() {
        if playlist.first == song.id {
            previousButton.isEnabled = false
        } else {
            previousButton.isEnabled = true
        }
        if playlist.last == song.id {
            nextButton.isEnabled = false
        } else {
            nextButton.isEnabled = true
        }
    }
    
    @objc func checkIfPlayerReady() {
        if player.status.rawValue == 1 {
            playerStartedTimer.invalidate()
            
            if !player.isPlaying {
                player.play()
            }
            
            newPlayerTimer(interval: 0.5)
        }
    }
    
    @objc func updateProgress() {
        if player.currentItem != nil {
            let timePlayed = Float(self.player.currentTime().value) / Float(self.player.currentTime().timescale)
            var timeLeft = Float(self.player.currentItem!.duration.value) / Float(self.player.currentItem!.duration.timescale) / 2
            if timePlayed >= 0.1 {
                timeSlider.value = Float(timePlayed)
                timeSlider.maximumValue = timeLeft
                setNowPlaying(timeLeft, timePlayed: timePlayed)
                timeLeft -= timePlayed
                currentTimeLabel.text = secondsToText(timePlayed)
                endTimeLabel.text = secondsToText(timeLeft)
                timeSlider.isEnabled = true
                pauseButton.isEnabled = true
                pauseButton.isHidden = !player.isPlaying
                playButton.isHidden = player.isPlaying
                toggleSkipPrevious()
                if loadingView.isAnimating {
                    loadingView.stopAnimating()
                }
                if Double(timeLeft) <= 0.5 {
                    if player.currentItem != player.items().last {
                        print("next")
                        skipSong()
                    } else {
                        print("last")
                        pause()
                        endOfPlaylist = true
                        
                    }
                }
            } else {
                loadingView.startAnimating()
                pauseButton.isHidden = true
            }
        }
    }
 
 
    func createPlaylist(_ startingSong:String) {
        //Since this is also called when the playlist is finished playing, reset all playlist variables
        self.player.pause()
        self.player.removeAllItems()
        self.loadedItems = 0
        self.timePlayed = 0
        if let _ = timer {
            timer.invalidate()
        }
        
        self.playlist = songs.map({$0.id})
        
        for _ in 0..<currentSongIndex {
            playlist.remove(at: 0)
        }
        
        //If the playlist is longer than 0 songs, load the first item
        if self.playlist.count > 0 {
            self.getStreamUrl(self.playlist[loadedItems])
        }
    }
    
    func setNowPlaying(_ dura: Float, timePlayed: Float) {
        let s = songs[playbackInstance.currentSongIndex]
        let currentImage = self.songImageView.image
        let albumArt = MPMediaItemArtwork.init(boundsSize: CGSize(width: 480, height: 360), requestHandler: { (size) -> UIImage in
            return currentImage ?? #imageLiteral(resourceName: "WhiteMusic")//self.albumCover
        })
        let songInfo: [String: Any]? = [
            MPMediaItemPropertyTitle: s.name,
            MPMediaItemPropertyArtist: s.artist,
            MPMediaItemPropertyArtwork: albumArt,
            MPMediaItemPropertyPlaybackDuration: dura,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: timePlayed
        ]
        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = self.nextButton.isEnabled
            MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = self.previousButton.isEnabled
            MPRemoteCommandCenter.shared().nextTrackCommand.addTarget(self, action: #selector(self.skipSong))
            MPRemoteCommandCenter.shared().previousTrackCommand.addTarget(self, action: #selector(self.previous))
            MPRemoteCommandCenter.shared().playCommand.addTarget(self, action: #selector(self.play))
            MPRemoteCommandCenter.shared().pauseCommand.addTarget(self, action: #selector(self.pause))
        }
    }
    
    func nothing() {
        
    }
    
    
    //Downloads the youtube stream URL based on songID, remember this is different than buffering but needs to be done
    func getStreamUrl(_ yt_id: String) {
        
        //First check if the URL is cached in NSUserDefaults
        if let urlString = UserDefaults.standard.object(forKey: yt_id) as? String {
            let expireRange = urlString.range(of: "expire=")
            let range = urlString.index(expireRange!.lowerBound, offsetBy: 7) ..< urlString.index(expireRange!.lowerBound, offsetBy: 16)
            //            let range = expireRange!.startIndex.advancedBy(n: 7) ..< expireRange!.startIndex.advancedBy(n: 16)
            //            let range = expireRange!.index(expireRange!.startIndex, offsetBy: 7)...expireRange!.index(expireRange!.startIndex, offsetBy: 16)
            let expiration = urlString[range]
            let expirationInt = Int(expiration)
            let currentTime = Int(Date().timeIntervalSince1970)+3600 //Give 1hr buffer for expiration date
            if expirationInt! > currentTime { //If it's cached and not expired, no need to download, just createPlayerItem
                let duration = (UserDefaults.standard.object(forKey: yt_id+".duration") as? Int ?? 0)
                self.createPlayerItem(URL(string: urlString)!, duration: duration)
                print("cached \(urlString)")
                return //No need to download stuffs
            }
        }
        
        XCDYouTubeClient.default().getVideoWithIdentifier(yt_id) { (video: XCDYouTubeVideo?, error: Error?) in
            print("LI \(self.loadedItems) \(self.playlist.count)")
            if let storedPVC = self.playbackInstance.storedPVC {
                if storedPVC != self {
                    self.invalidateTimers()
                    self.dismiss(animated: false, completion: nil)
                    return
                }
            }
            if self.loadedItems >= self.playlist.count {
                return //kill the original playlist loading
            }
            if error != nil {
                // print(error)
                //If there was an error with URL downloading
                if error!._domain == XCDYouTubeVideoErrorDomain {
                    //Specifically if the error was restricted playback, we should delete the song from the playlist, and ideally from the database/server because we'll never be able to play it again
                    //                    if error.code == XCDYouTubeErrorCode.RestrictedPlayback.rawValue {
                    //                        var objectsToDelete = realm.objects(InboxSong).filter("yt_id == %@", yt_id)
                    //                        realm.write(){
                    //                            realm.delete(objectsToDelete)
                    //                        }
                    //                        self.playlist.removeAtIndex(self.loadeditems)  //TODO
                    //                        println("this will happen once, but it shouldn't break anything")
                    //                        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
                    //                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
                    //                            inboxViewController.tableView.reloadData()
                    //                        }
                    //                        //After deleting the song from the playlist, I load the next song. The next song now has index self.loadeditems since we just deleted the object at index self.loadeditems
                    //                        if self.loadeditems < self.playlist.count {
                    //                            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
                    //                        }
                    //                    }
                    //If the error was something else, I'm currently not handling this properly. It would likely be a network error so it looks like I just stop trying to load songs
                }
                print("XCD error \(error)")
            } else {
                //If the url was loaded successfully, grab the streamURL we want (by default an array of streams corresponding to different formats is downloaded
                //Audio only is video.streamURLs[140] but causes delay in notification
                //print("vid: \(video)")
                if let url = (video?.streamURLs[NSNumber(value: 140)]!)! as NSURL! {
                    UserDefaults.standard.set(url.absoluteString, forKey: video!.identifier)
                    UserDefaults.standard.set(Int(video!.duration), forKey: video!.identifier+".duration")
                    if self.playlist[self.loadedItems] == video!.identifier {
//                        print("\n \(String(describing: self.playlist))")
//                        print(self.playlist[self.loadedItems])
//                        print("\(video!.identifier) \n")
                        self.createPlayerItem(url as URL, duration: Int(video!.duration))
                        //print("create item url \(url.absoluteString)")
                        print("\(self.loadedItems) \(self.playlist)")
                        return //Since every thing else needs to get next streamUrl
                    } else {
                        print("out of sync")
                    }
                }
            }
        }
        
        //If it wasn't cached, or cache was expired, download the url from XCDYoutubeClient
        //HERE 2020
        /*
        XCDYouTubeClient.default().getVideoWithIdentifier(yt_id, completionHandler: { video, error in
        //create new playlist
        if self.loadeditems >= self.playlist.count {
            return
         }
         if error != nil {
         // print(error)
         //If there was an error with URL downloading
         if error!._domain == XCDYouTubeVideoErrorDomain {
         //Specifically if the error was restricted playback, we should delete the song from the playlist, and ideally from the database/server because we'll never be able to play it again
         //                    if error.code == XCDYouTubeErrorCode.RestrictedPlayback.rawValue {
         //                        var objectsToDelete = realm.objects(InboxSong).filter("yt_id == %@", yt_id)
         //                        realm.write(){
         //                            realm.delete(objectsToDelete)
         //                        }
         //                        self.playlist.removeAtIndex(self.loadeditems)  //TODO
         //                        println("this will happen once, but it shouldn't break anything")
         //                        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
         //                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
         //                            inboxViewController.tableView.reloadData()
         //                        }
         //                        //After deleting the song from the playlist, I load the next song. The next song now has index self.loadeditems since we just deleted the object at index self.loadeditems
         //                        if self.loadeditems < self.playlist.count {
         //                            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
         //                        }
         //                    }
         //If the error was something else, I'm currently not handling this properly. It would likely be a network error so it looks like I just stop trying to load songs
            }
         } else {
            //If the url was loaded successfully, grab the streamURL we want (by default an array of streams corresponding to different formats is downloaded
            //Audio only is video.streamURLs[140] but causes delay in notification
            //print("vid: \(video)")
            if let url = video?.streamURLs[140] {
                UserDefaults.standard.set(url.absoluteString, forKey: video!.identifier)
                UserDefaults.standard.set(Int(video!.duration), forKey: video!.identifier+".duration")
                if self.playlist[self.loadeditems] == video!.identifier {
                    self.createPlayerItem(url as URL, duration: Int(video!.duration))
                    return //Since every thing else needs to get next streamUrl
                } else {
                    //The video identifier may not correspond because we created a new playlist in the middle of loading the first (you probably don't need to worry about this)
                    print("out of sync, likely playlist changed")
                }
            }
            }
        })//here
        */
    }
 
    //Create player item creates the AVPlayerItem for each song
    func createPlayerItem(_ url: URL, duration: Int) {
        //Create the AVPlayerItem
        let playerItem = AVPlayerItem(url: url)
        //Store a reference to it in self.loadeditems (I'm not sure I use the reference too much, but figured it'd be good to have)
        //        self.playlist[self.loadeditems].item = playerItem
        //Add a notification handler for when the AVPlayerItem is finished playing. This is important to increment the currentSong index as well as update the UI to show the new song
        //        NSNotificationCenter.defaultCenter().addObserverForName(AVPlayerItemDidPlayToEndTimeNotification, object: playerItem, queue: NSOperationQueue.mainQueue(), usingBlock: { notification in
        //            println("Ended")
        //            self.currentSongIndex+=1
        //            self.skipSong()
        //        })
        //Insert the playerItem we created at the end of the AVQueuePlayer (essentially at the end of the playlist)
        self.player.insert(playerItem, after: nil)
        playerItems.append(playerItem)
        //In case the first song in the playlist was the deleted song (due to youtube error), and the player widget showed the title/artist of the deleted song, we need to update it
        //        if self.loadeditems == 0 && self.titleLabel.text != self.playlist[self.loadeditems].title {
        //            self.setNowPlaying() //Covers case where deleted song happened to be chosen first
        //        }
        //Increment loaded items
        self.loadedItems+=1
        //If the song was played but URL hadn't been loaded yet, I disable some of the UI buttons and show "..." in place of the play button. This simply reverts that
        if self.loadedItems-1 == self.currentSongIndex && !self.playButton.isEnabled {
            self.playButton.isEnabled = true
        }
        
        //If not all songs have been loaded yet, load the next song!
        if self.loadedItems < self.playlist.count {
            self.getStreamUrl(self.playlist[self.loadedItems])
        }
    }
    
    //    func loadVideo(videoID: String) {
    //        let embededHTML = "<html><body style='margin:0px;padding:0px;'><script type='text/javascript' src='http://www.youtube.com/iframe_api'></script><script type='text/javascript'>function onYouTubeIframeAPIReady(){ytplayer=new YT.Player('playerId',{events:{onReady:onPlayerReady}})}function onPlayerReady(a){a.target.playVideo();}</script><iframe id='playerId' type='text/html' width='200' height='200' src='http://www.youtube.com/embed/\(videoID)?enablejsapi=1&rel=0&playsinline=1&autoplay=1' frameborder='0'></body></html>"
    //
    //        //        webView.loadHTMLString(embededHTML, baseURL: NSBundle.mainBundle().resourceURL)
    //
    //        let playerVars = ["autoplay" : 1, "playsinline" : 1, "width" : 0, "height" : 0, "origin" : "http://www.loganpratt.me"]
    //        ytPlayer.loadWithVideoId(videoID, playerVars: playerVars)
    ////        ytPlayer.loadPlayThisByVideos(songs.songIds, index: Int32(currentSongIndex), startSeconds: Float(0.0), suggestedQuality: YTPlaybackQuality.Auto)
    //    }
    
    
    func getDataFromUrl(_ urL:URL, completion: @escaping ((_ data: Data?) -> Void)) {
        URLSession.shared.dataTask(with: urL) { (data, response, error) in
            completion(data)
            }.resume()
    }
    
    func downloadImage(_ url:URL){
        //        println("Started downloading \"\(url.lastPathComponent!.stringByDeletingPathExtension)\".")
        getDataFromUrl(url) { data in
            DispatchQueue.main.async {
                //                println("Finished downloading \"\(url.lastPathComponent!.stringByDeletingPathExtension)\".")
                self.albumCover = UIImage(data: data!)!
                self.songImageView.image = self.albumCover
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func pauseVideo(_ sender: AnyObject) {
        if timer.isValid {
            pause()
            togglePausePlayButton()
            timer.invalidate()
        }
    }
    
    @IBAction func playVideo(_ sender: AnyObject) {
        if !timer.isValid {
            play()
            togglePausePlayButton()
            //timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(PlaybackViewController.updateProgress), userInfo: nil, repeats: true)
//            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { (timerValue) in
//                if !self.endOfPlaylist {
//                    self.updateProgress()  // call the selector function here
//                } else {
//                    print("inv")
//                    timerValue.invalidate()
//                    self.invalidateTimers()
//                }
//            })
            newPlayerTimer(interval: 0.5)
            //        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: "updateProgress", userInfo: nil, repeats: true)
        }
    }
    
    func newPlayerTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { (timerValue) in
            if !self.endOfPlaylist {
                self.updateProgress()  // call the selector function here
            } else {
                print("inv")
                timerValue.invalidate()
                self.invalidateTimers()
            }
        })
    }
    
    func togglePausePlayButton() {
        pauseButton.isHidden = !pauseButton.isHidden
        playButton.isHidden = !playButton.isHidden
    }
    
    @objc func play() -> MPRemoteCommandHandlerStatus {
        isPlaying = true
        //        ytPlayer.playVideo()
        self.player.play()
        if(self.player.rate != 0 && self.player.error == nil) {
            return MPRemoteCommandHandlerStatus.success
        }else {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
    }
    
    @objc func pause() -> MPRemoteCommandHandlerStatus{
        isPlaying = false
        //        ytPlayer.pauseVideo()
        self.player.pause()
        return MPRemoteCommandHandlerStatus.success
    }
    
    @objc func seekTo(_ seconds: Float, seekAhead: Bool) {
        //        ytPlayer.seekToSeconds(seconds, allowSeekAhead: seekAhead)
    }
    
    @objc func secondsToText(_ seconds: Float) -> String {
        let minutes = floor(seconds/60)
        //        let minutes = seconds / 60
        let seconds = round(seconds - minutes * 60)
        var secondsString = "\(Int(seconds))"
        
        if seconds < 10 {
            secondsString = "0\(secondsString)"
        }
        
        return "\(Int(minutes)):\(secondsString)"
    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        if timer.isValid {
            currentTimeLabel.text = secondsToText(sender.value)
            if let _ = player.currentItem {
                player.seek(to: CMTimeMakeWithSeconds(Float64(sender.value), preferredTimescale: player.currentItem!.currentTime().timescale))
            }
        }
    }
 
    
    @IBAction func nextSong(_ sender: AnyObject) {
        //currentSongIndex+=1
        skipSong()
        //if currentSongIndex <= playlist.count {
        
        //self.player.replaceCurrentItem(with: playerItems[currentSongIndex-firstIndex])
        //}
    }
    
    @objc func skipSong() -> MPRemoteCommandHandlerStatus{
        if !nextButton.isEnabled {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        if let waitTimer = waitTimer {
            waitTimer.invalidate()
        }
        currentSongIndex+=1
        
        if currentSongIndex < songs.count && currentSongIndex >= 0 {
            setUpView()
            checkQueue()
        }
        return MPRemoteCommandHandlerStatus.success
    }
    
    
    @objc func checkQueue() {
        if loadedItems >= currentSongIndex - firstIndex {
            if let _ = player.currentItem {
                if let _ = playerItems.index(of: player.currentItem!) {
                    for _ in 0..<(currentSongIndex - playerItems.index(of: player.currentItem!)! - firstIndex) {
                        player.advanceToNextItem()
                    }
                    play()
                    loadingView.stopAnimating()
                    pauseButton.isHidden = false
                }
            }
        } else {
            pause()
            pauseButton.isHidden = true
            loadingView.startAnimating()
            print("pause and load \(loadedItems) \(currentSongIndex)")
            waitTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(PlaybackViewController.checkQueue), userInfo: nil, repeats: false)
        }
    }
    
    @IBAction func previousSong(_ sender: AnyObject) {
        previous()
    }
    
    @objc func previous() -> MPRemoteCommandHandlerStatus{
        if !previousButton.isEnabled {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        endOfPlaylist = false
        currentSongIndex-=1
        playerItems[currentSongIndex-firstIndex].seek(to: CMTimeMakeWithSeconds(Float64(0), preferredTimescale: playerItems[currentSongIndex-firstIndex].currentTime().timescale))
        player.replaceCurrentItem(with: playerItems[currentSongIndex-firstIndex])
        playerItems[currentSongIndex-firstIndex+1].seek(to: CMTimeMakeWithSeconds(Float64(0), preferredTimescale: playerItems[currentSongIndex-firstIndex+1].currentTime().timescale))
        player.insert(playerItems[currentSongIndex-firstIndex+1], after: player.currentItem)
        setUpView()
        
        
        return MPRemoteCommandHandlerStatus.success
    }
    
    public func invalidateTimers() {
        if let _ = timer {
            timer.invalidate()
        }
        if let _ = waitTimer {
            waitTimer.invalidate()
        }
        if let _ = playerStartedTimer {
            playerStartedTimer.invalidate()
        }
    }
    
    override func remoteControlReceived(with event: UIEvent?) {
        let rc = event!.subtype
        
        print("received remote control \(rc.rawValue)") // 101 = pause, 100 = play
        //        switch rc.rawValue {
        //        case 100:
        //            print("play")
        //            playButton.isHidden = true
        //            pauseButton.isHidden = false
        //            play()
        //            break
        //        case 101:
        //            print("pause")
        //            playButton.isHidden = false
        //            pauseButton.isHidden = true
        //            pause()
        //            break
        //        case 104:
        //            print("skip")
        //            //            glFinish()
        //            //            ytPlayer.removeWebView()
        //            //currentSongIndex+=1
        //            skipSong()
        //            //            if currentSongIndex <= playlist.count + 1 {
        //            //self.player.advanceToNextItem()
        //            //            }
        //            break
        //        case 105:
        //            print("previous")
        //            currentSongIndex-=1
        //            previous()
        //            //            self.timeSlider.maximumValue = 1
        //            //            skipSong()
        //            //            player.pause()
        //            //            player.removeAllItems()
        //        //            createPlayThis(songId)
        //        default:break
        //        }
    }
    
    @objc func toPlaylist() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let playlistViewController = storyBoard.instantiateViewController(withIdentifier: "playlist") as! PlaylistViewController
        self.present(playlistViewController, animated: true, completion: nil)
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension CMTime {
    var durationText:String {
        let totalSeconds = CMTimeGetSeconds(self)
        let hours:Int = Int(totalSeconds / 3600)
        let minutes:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60) / 60)
        let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
