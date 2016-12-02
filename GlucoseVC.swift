//
//  GlucoseVC.swift
//  HealthHelper
//
//  Created by Alan Youngblood on 8/6/15.
//  Copyright (c) 2015 Alan Youngblood. All rights reserved.
//

import UIKit
import HealthKit
import Foundation

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}

let mgUnit = HKUnit.gramUnit(with: .milli)
let dLUnit = HKUnit.literUnit(with: .deci)
let mgdLUnit = mgUnit.unitDivided(by: dLUnit)

class GlucoseVC: UIViewController, UIDocumentMenuDelegate, UIDocumentPickerDelegate, UITableViewDelegate {

//  MARK:  ------------ Variables -----------
    
    var csvImportDict = NSMutableDictionary()
    var csvImportArray = NSMutableArray()
    var keysArray = NSMutableArray()
    var docString = NSString()
    var dateFormatter = DateFormatter()
    
    let myUTIs = ["public.content"]
    
    var glucoseSamples = NSMutableArray()
    var myNumber:Double = 0.0
    
//  MARK: ----------------- IBOutlets
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var fixErrors: UIButton!
    @IBOutlet var importToHealth: UIButton!
    @IBOutlet var clearAll: UIButton!
    
//  MARK: ------------------ IBActions ----------------
    
    @IBAction func iCloudButton(_ sender: UIButton) {

        let importMenu = UIDocumentMenuViewController(documentTypes: myUTIs, in: UIDocumentPickerMode.import)
        let picker = UIDocumentPickerViewController(documentTypes: self.myUTIs, in: UIDocumentPickerMode.open)
        picker.delegate = self as UIDocumentPickerDelegate
        self.present(picker, animated: true, completion: nil)
        importMenu.delegate = self
        self.present(importMenu, animated: true, completion: nil)
    }
    
    @IBAction func clearAction(_ sender: UIButton) {
        glucoseSamples.removeAllObjects()
        tableView.reloadData()
        clearAll.isHidden = true
        importToHealth.isHidden = true
        
    }
    
    
    @IBAction func ImportToHealthButton(_ sender: UIButton) {
//    println("tapped Import to Health")
//           ***Comment these out, except when you want to send the data to healthkit store
        for i in 0...glucoseSamples.count - 1 {
            hkStoreSaveObj(glucoseSamples[i] as! HKQuantitySample)
        }
        
//            Purge the loaded samples and then reload the view:
        glucoseSamples.removeAllObjects()
        tableView.reloadData()
    }
//   MARK: -----------------(re)Intiialize Function------
    
    
    func initializeArrays() {
        glucoseSamples.removeAllObjects()
        keysArray.removeAllObjects()
        csvImportArray.removeAllObjects()
        csvImportDict.removeAllObjects()
    }
    

//   MARK: ----------------tableView Setup--------------
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return glucoseSamples.count
        
    }
    
    private func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell{
        
        let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "Cell")

        
        let aSample: HKQuantitySample = glucoseSamples[(indexPath as NSIndexPath).row] as! HKQuantitySample
        
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16.0)
        cell.textLabel?.text = "\(aSample.quantity)" + ": \(aSample.startDate)".replacingOccurrences(of: "+0000", with: "", options: [], range: nil)
        
        return cell
    }
    
    private func tableView(_ tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: IndexPath){
        //        println("index: \(indexPath.row)")
        //        println("count: \(glucoseSamples.count)")
        if (indexPath as NSIndexPath).row == 0 {
            
            if editingStyle == UITableViewCellEditingStyle.delete {
                glucoseSamples.removeObject(at: (indexPath as NSIndexPath).row)
                
                tableView.reloadData()
            }
        }
//        else if editingStyle == UITableViewCellEditingStyle.delete {
//            
//            glucoseSamples.remove(at: indexPath.row)
//            
//            tableView.reloadData()
//        }
        
    }
    
//   MARK: ---------- UIDocumentMenu Setups
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self as UIDocumentPickerDelegate
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    
    func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController) {
                print("Closed doc picker menu")
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
//        Clear the current table data before loading anything new
        initializeArrays()
                print("Document: \(url)")
        
//        NSFileManager.defaultManager().setAttributes([NSFileModificationDate: NSDate().timeIntervalSinceNow], ofItemAtPath: url.absoluteString)
        if let document:Data = try? Data(contentsOf: url) {
//        print(document)

        docString = NSString(data: document, encoding: String.Encoding.utf8.rawValue)!
//        print(docString)
        parseCSVToGlucoseSamples(docString)
            tableView.reloadData()
        }
        tableView.reloadData()
        importToHealth.isHidden = false
        clearAll.isHidden = false
    }
    
//  MARK:  ------------- HK operations functions setup ----------
    func hkStoreSaveObj(_ glucoseSample: HKQuantitySample) {
        healthKitStore.save(glucoseSample, withCompletion: { (success, error) -> Void in
            //                            println("sent BG \(glucoseSample)")
            if success {
                //                                println("success: \(success)")
            } else {
                print("error: \(error)")
            }
        })
    }
    


    
//  MARK:  ------------- Parsing Function ----------
    func parseCSVToGlucoseSamples(_ fileContents: NSString) {
        
        
        let usedContents = fileContents.components(separatedBy: "Index")
        
        var rows = usedContents[1].components(separatedBy: "\n") 

        rows[0] = "Index" + rows[0]
        
//        print(rows[0])
        
        let headers = rows[0].components(separatedBy: ",")
        
        for header in headers {
            let header = header.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
            csvImportDict[header] = ""
            keysArray.add(header)
        }

        
        for row:String in rows {
            var columns = row.components(separatedBy: ",")
//            Check for extra columns and get rid of them.
            let diff = columns.count - keysArray.count
            if diff > 0 {
                for _ in 1...diff {
                    columns.removeLast()
                }
            }
//            print("columns: \(columns)")
//            print("# of Columns: \(columns.count)")
            if columns.count == keysArray.count {
//                var lineDict = NSMutableDictionary(objects: columns, forKeys: keysArray as [AnyObject])
                var lineDict = [String:String]()

                lineDict = NSDictionary(objects: columns, forKeys: keysArray.copy() as! [NSCopying]) as! [String : String]
                csvImportArray.add(lineDict)
//                print(" \(lineDict)")
            
            }
        }
//        print("keysArray: \(keysArray)")
//        print("csvImportDict: \(csvImportDict)")
        
        let bgStr = "BG Reading (mg/dL)"
//        print(csvImportArray[1])
        
        var timeStamp = ""
        
        for index in 1...csvImportArray.count - 1 {

            
            dateFormatter.dateFormat = "MM/dd/yy HH:mm:ss"
            dateFormatter.timeZone = TimeZone.current
//            print(csvImportArray[5])
            
            let dataPtBG = (csvImportArray[index] as AnyObject).value(forKey: bgStr) as! String
//            var lastSampleDate:NSDate = NSDate.distantPast()
            
            if dataPtBG != "" {
                
                myNumber = dataPtBG.toDouble()!
                let dateString:String = (csvImportArray[index] as AnyObject).value(forKey: "Timestamp") as! String
                let date = dateFormatter.date(from: dateString)
                
                let glucoseQuantity = HKQuantity(unit: mgdLUnit, doubleValue: myNumber)
                
                let glucoseSample = HKQuantitySample(type: HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!, quantity: glucoseQuantity, start: date!, end: date!)
                
                //                Check for immediate duplicates and don't add them to glucoseSamples
                let ts = "Timestamp"
                
                if (csvImportArray[index] as AnyObject).value(forKey: ts) as! String != timeStamp {
                    glucoseSamples.add(glucoseSample)
                }
                //                    lastSampleDate =
                //                    println(lastSample)
                timeStamp = (csvImportArray[index] as AnyObject).value(forKey: "Timestamp") as! String
                
                
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        importToHealth.isHidden = true
        fixErrors.isHidden = true
        clearAll.isHidden = true
        
        if let iCloudDocumentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            if (!FileManager.default.fileExists(atPath: iCloudDocumentsURL.path, isDirectory: nil)) {
                do {
                    try FileManager.default.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch _ {
                }
            }
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
