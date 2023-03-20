# Paperless Extractor

This app is designed to pull all the PDFs from a Paperless library and put them in folders based on year and month of the item.

It will name each PDF using the merchant/title in the PDF as well as the date (these are pulled from the keywords in the PDF).

Caveats:
- Some PDFs don't have keywords in the metadata; by default Paperless stores this information in the keywords, but if it is turned off or
somehow Paperless didn't write the data to the PDF, this app can't pull the information.
- Files that don't have enough information to properly name will be placed in an Unclassified folder.
- There has been limited testing of this app. It will not modify your original library.
- This is a work in progress and may not be the best example of SwiftUI and/or structured concurrency; I'm using it as a learning experience.

Note:
This was written without using any source code from Paperless. It simply walks the Paperless library (which is a folder), finds all the PDFs, opens each PDF and gets the keywords in it.

No special knowledge about the format of the data was required.


No warranty is implied about what this app can and cannot do. Use at your own risk.


While I am the original author of Paperless, I am not affiliated with the company that currently owns Paperless.
