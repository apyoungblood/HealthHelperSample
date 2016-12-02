# HealthHelperSample

This is a sample taken directly from a ViewController Swift file in Xcode. This particular code snippet shows an implementation of the loading of an external file (in this case from iCloud) that is in the .CSV format. From there, the App parses the relevant data (In this case we are looking only at Blood Glucose values) which it stores and presents to the user for editing or approval. The user may then send the data to import into the HealthKitStore which is a secure datastore for end-user biometric data accessible in the Apple Health App.

Due to rapid version changes of Swift language, this code will compile, but currently crashes when importing data. This likely has something to do with the forced use of the "try" keyword and changes in error handling that have come with Swift 3.0.
