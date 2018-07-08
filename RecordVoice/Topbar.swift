//
//  Topbar.swift
//  RecordVoice
//
//  Created by Jay Mehta on 18/03/16.
//  Copyright © 2016 Jay Mehta. All rights reserved.
//

import Foundation
import UIKit

class Topbar : UIViewController
{
    var btnRight : UIButton?{
        didSet {
            self.btnRight?.translatesAutoresizingMaskIntoConstraints=false;
            //self.btnRight?.setTitle("", forState:UIControlStateNormal)
            self.btnRight?.setTitle("", forState:.Normal)
            
        }
    }
    
    var btnLeft  : UIButton?{
        didSet {
            self.btnLeft?.translatesAutoresizingMaskIntoConstraints=false;
            self.btnLeft?.setTitle("", forState:.Normal)
        }
    }
    var topView  : UIView?{
         didSet {
           self.topView?.translatesAutoresizingMaskIntoConstraints=false;
            
        }
    }
    var lblTopTitle : UILabel?{
        didSet {
            self.lblTopTitle?.translatesAutoresizingMaskIntoConstraints=false;
            self.lblTopTitle?.text="";
        }
    }
    
    override func viewDidLoad() {
     
        self.initView();
        
    }
    
    func initView()
    {
        self.topView = UIView();
        self.view .addSubview(topView!);
        
        self.btnLeft = UIButton();
        topView?.addSubview(self.btnLeft!);
        
        self.btnRight = UIButton();
        topView?.addSubview(self.btnRight!);
        
        self.lblTopTitle = UILabel()
        topView?.addSubview(self.lblTopTitle!);
        
        

        
    }
}