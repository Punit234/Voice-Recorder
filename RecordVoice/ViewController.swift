//
//  ViewController.swift
//  RecordVoice
//
//  Created by Jay Mehta on 15/03/16.
//  Copyright © 2016 Jay Mehta. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController,AVAudioRecorderDelegate,AVAudioPlayerDelegate,PutControllerDelegate {

    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var audioRecorder: AVAudioRecorder?
    var recordingSession: AVAudioSession!
    var audioPlayer: AVAudioPlayer?
    var levelTimer = NSTimer()
    var lowPassResults: Double = 0.0
    var isBlowDetected : Bool = false;
    var sendFile : PutController = PutController()
    
    let username = "developer@reviewprototypes.com"
    let password = "[@ZN](,xVZlL"
    
    //MARK: VC LIFE CYCLE METHODS
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        activityIndicator.hidden = true;
        
    }
    
    override func viewDidAppear(animated: Bool) {

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - SHOW PERMISSION ALERT
    func showPermissionAlert() {
        //
       let alert=UIAlertController(title: "Allow Microphone", message: "This is to be able to be heard on recording", preferredStyle: UIAlertControllerStyle.Alert);
        //no event handler (just close dialog box)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil));
        //event handler with closure
        alert.addAction(UIAlertAction(title: "Open Setting", style: UIAlertActionStyle.Default, handler: {
            (action:UIAlertAction) in
            
           UIApplication.sharedApplication().openURL(NSURL(string:"prefs:root=RecordVoice&path=Microphone")!)
            
        }));
        presentViewController(alert, animated: true, completion: nil);
    }
    
    //MARK: - BUTTON METHODS
    @IBAction func btnStartPress(sender: AnyObject) {
        
        recordingSession = AVAudioSession.sharedInstance()
        do {
            
            recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    if allowed {
                        // Yes, Allowed !
                        print("Allowd Permission Record!!")
                        self.initalizeRecorder ()
                        self.isBlowDetected = false;
                        self.audioRecorder!.record()
                        self.startLoadingAnimation();
                        //instantiate a timer to be called with whatever frequency we want to grab metering values
                        self.levelTimer = NSTimer.scheduledTimerWithTimeInterval(0.02, target: self, selector: Selector("levelTimerCallback"), userInfo: nil, repeats: true)
                        
                    } else {
                        // failed to record!
                        self.showPermissionAlert();
                        print("Failed Permission Record!!")
                    }
                }
            }
        } catch {
            // failed to record!
            print("Failed Permission Record!!")
        }
        
    }
    
    @IBAction func btnStopPress(sender: AnyObject) {
        
        finishRecording(success:true)
        
    }
    
    @IBAction func btnPlay(sender: AnyObject) {
        
        if audioRecorder?.recording == false {
           
            let stringDir:NSString = self.getDocumentsDirectory();
            let audioFilename = stringDir.stringByAppendingPathComponent("recording.m4a")
            
            let fileManager:NSFileManager = NSFileManager.defaultManager()
            
            //IF FILE NOT EXITST THEN RETURN
            if fileManager.fileExistsAtPath(audioFilename) == false
            {
                print("File not exist at path!!!");
                return;
            }
            
            let audioURL = NSURL(fileURLWithPath: audioFilename)
            
            audioPlayer = AVAudioPlayer()
            do { audioPlayer = try AVAudioPlayer(contentsOfURL: audioURL, fileTypeHint: nil) }
            catch let error as NSError { print("Player Error \(error.description)") }
            
            audioPlayer!.numberOfLoops = 0
            audioPlayer!.prepareToPlay()
            audioPlayer!.play()
            audioPlayer!.delegate = self;
            
            if audioPlayer!.playing
            {
                print("Playing ....")
            }
            else
            {
                print("Not Playing....");
            }
        }
    }
    
    @IBAction func btnUpload(sender: AnyObject) {
        
        self.uploadDataOnFTP();
        
    }
    
     //MARK: - INIT AVAUDIORECORDER AND SESSION
     func initalizeRecorder ()
     {
        do {
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
            
        }catch{
            print(error);
        }
        
        self.removeFile("recording.m4a");
        let stringDir:NSString = self.getDocumentsDirectory();
        let audioFilename = stringDir.stringByAppendingPathComponent("recording.m4a")
        let audioURL = NSURL(fileURLWithPath: audioFilename)
        print("File Path : \(audioFilename)");
       
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderBitRateKey:12800 as NSNumber,
            AVLinearPCMBitDepthKey:16 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]
        
      
        do {
            if audioRecorder == nil
            {
                audioRecorder = try AVAudioRecorder(URL: audioURL, settings: settings )
                audioRecorder!.delegate = self
                audioRecorder!.prepareToRecord();
                audioRecorder!.meteringEnabled = true;
            }
            audioRecorder!.recordForDuration(NSTimeInterval(5.0));
         } catch {
            finishRecording(success: false)
        }
    }
    
    
    
    //This selector/function is called every time our timer (levelTime) fires
    func levelTimerCallback() {
        //we have to update meters before we can get the metering values
        if audioRecorder != nil
        {
            audioRecorder!.updateMeters()
            
            let ALPHA : Double = 0.05;
            let peakPowerForChannel : Double = pow(Double(10.0), (0.05) * Double(audioRecorder!.peakPowerForChannel(0)));
            lowPassResults = ALPHA * peakPowerForChannel + Double((1.0) - ALPHA) * lowPassResults;
            print("low pass res = \(lowPassResults)");
            if (lowPassResults > 0.45 ){
               print("Mic blow detected");
               self.isBlowDetected = true;
            }
            
        }
    }
    
    //MARK: FILE OPERATION METHOD
    //GET DOCUMENT DIR PATH
    func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    //Remove File From Path
    func removeFile(itemName:String) {
       
        do{
            let fileManager:NSFileManager = NSFileManager.defaultManager()
            let stringDir:NSString = self.getDocumentsDirectory();
            let filePath = stringDir.stringByAppendingPathComponent(itemName)
            if fileManager.fileExistsAtPath(filePath)
            {
                try fileManager.removeItemAtPath(filePath)
            }
        }
        catch
        {
            print("Error Remove File :\(error)");
        }
        
    }
    
    
    //MARK - METHODS
    
    func finishRecording(success success: Bool) {
        
        if audioRecorder != nil
        {
            audioRecorder!.stop()
            audioRecorder = nil;
            self.levelTimer.invalidate()
        }
        self.stopLoadingAnimation();
        
        if self.isBlowDetected == false
        {
            print("No voice detected. Speak again !!! as per limit")
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("Error AudioSession SetActive(False) : \(error)");
        }
        
    }

    func uploadDataOnFTP(){
        
        if(audioRecorder?.recording == true)
        {
            return;
        }
        let filename = "ftp://ftp.reviewprototypes.com/projects_dev/android_assignment/ios_upload/recorderJM.wav"
        
        // Converting the messing filename into one that can be used as a URL
        let convertedStringForURL = filename.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
        let uploadUrl = NSURL(string: convertedStringForURL!)
        
        let fileManager:NSFileManager = NSFileManager.defaultManager()
        let stringDir:NSString = self.getDocumentsDirectory();
        let filePath = stringDir.stringByAppendingPathComponent("recording.m4a")
        if fileManager.fileExistsAtPath(filePath)
        {
            let dataForFile : NSData =  NSData(contentsOfFile: filePath)!
            self.startLoadingAnimation();
            // USE THE OBJECTIVE-C VARIABLE
            sendFile._delegatePutVC = self;
            sendFile.startSend(dataForFile, withURL: uploadUrl, withUsername: username, andPassword: password)
        }
        // let convertedStr = NSString(data: dataForFile, encoding: NSUTF8StringEncoding)
        // _ = convertedStr!.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        //let dataToUpload = data.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
    }
  
    
    
    //MARK: - AUDIO RECORDER DELEGATE
    /*

    iOS might stop your recording for some reason out of your control, such as if a phone call comes in. We are the delegate of the audio recorder, so if this situation crops up you'll be sent a audioRecorderDidFinishRecording() message that you can pass on to finishRecording() like this:
    
    */
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Did Finish Called!!!")
        if flag==true {
            print("Flag True !!!")
            finishRecording(success: false)
        }
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if flag
        {
            print("Successfully Played !!");
        }
        
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        print("Play Error Did Occur : \(error?.description)")
    }
    
    
    
    //MARK: - PUTCONTROLLER DELEGATE (UPLOADING PROCESSS)
    
    func didFail(error: String!) {
        print("failed");

    }
    func didStart() {
        print("start");
    }
    func didSuccessfullyUploaded() {
        self.stopLoadingAnimation()
        print("sucess");

    }
    func didUploading() {
        print("uploading");

    }
    
    //MARK: LOADING INDICATOR METHOD
    func startLoadingAnimation()
    {
        activityIndicator.hidden = false;
        activityIndicator.startAnimating();
    }
    
    func stopLoadingAnimation()
    {
        activityIndicator.hidden = true;
        activityIndicator.stopAnimating();
    }
    
    func isLoadingRunning() -> Bool
    {
        return activityIndicator.isAnimating();
    }

}

