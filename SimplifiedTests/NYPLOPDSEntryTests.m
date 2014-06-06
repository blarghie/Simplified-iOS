#import <SMXMLDocument/SMXMLDocument.h>
#import <XCTest/XCTest.h>

#import "NSDate+NYPLDateAdditions.h"
#import "NYPLOPDSAcquisitionFeed.h"
#import "NYPLOPDSEntry.h"

@interface NYPLOPDSEntryTests : XCTestCase

@property (nonatomic) NYPLOPDSEntry *entry;

@end

@implementation NYPLOPDSEntryTests

- (void)setUp
{
  [super setUp];
  
  NSData *data = [NSData dataWithContentsOfFile:
                  [[NSBundle bundleForClass:[self class]]
                   pathForResource:@"single_entry"
                   ofType:@"xml"]];
  assert(data);
  
  SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
  assert(document);
  
  NYPLOPDSAcquisitionFeed *acquisitionFeed =
    [[NYPLOPDSAcquisitionFeed alloc] initWithDocument:document];
  assert(acquisitionFeed);
  
  self.entry = acquisitionFeed.entries[0];
  assert(self.entry);
}

- (void)tearDown
{
  [super tearDown];
  
  self.entry = nil;
}

- (void)testAuthorNames
{
  XCTAssertEqual(self.entry.authorNames.count, 2);
  XCTAssertEqualObjects(self.entry.authorNames[0], @"James, Henry");
  XCTAssertEqualObjects(self.entry.authorNames[1], @"Author, Fictional");
}

- (void)testIdentifier
{
  XCTAssertEqualObjects(self.entry.identifier,
                        @"http://localhost/works/4c87a3af9d312c5fd2d44403efc57e2b");
}

- (void)testLinksPresent
{
  XCTAssert(self.entry.links);
}

- (void)testTitle
{
  XCTAssertEqualObjects(self.entry.title, @"The American");
}

- (void)testUpdated
{
  NSDate *date = self.entry.updated;
  
  XCTAssert(date);
  
  NSDateComponents *dateComponents = [date UTCComponents];
  
  XCTAssertEqual(dateComponents.year, 2014);
  XCTAssertEqual(dateComponents.month, 6);
  XCTAssertEqual(dateComponents.day, 2);
  XCTAssertEqual(dateComponents.hour, 16);
  XCTAssertEqual(dateComponents.minute, 59);
  XCTAssertEqual(dateComponents.second, 57);
}

@end