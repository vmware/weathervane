/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/**
 * Default Configuration Object
 */
auction.conf = {
    device : 'computer',                            // Device rendering the application (changes to "mobile" depending on the user agent)
    sessionCookieName : 'auctionSession',        // Name of the Cookie that will store the session info in the browser
    auctionCookieName : 'auctionAuctions',        // Name of the Cookie that will store the auctions currently attended
    urlRoot : '/auction/',   // Path to the API service
    tplRoot : './templates/',                       // Path to the Templates directory
    userIdUrlKey : '{userid}',                // Key in the api urls that's gonna be replaced with the actual accountid
    pageUrlKey : '{page}',                          // Key in the api urls that's gonna be replaced with the page number
    auctionIdUrlKey : '{auctionId}',                   // Key in the api urls that's going to be replaced with the auction Id
    itemIdUrlKey : '{itemId}',                        // Key in the api urls that's going to be replaced with the item Id
    bidIdUrlKey : '{bidId}',                        // Key in the api urls that's going to be replaced with the bid Id
    lastBidCountUrlKey : '{bidCount}',                      // Key in the api urls that's going to be replaced with a bid count
    currency : '$',                                 // Current currency is dollars
    thousandsSep : ',',                             // separator char for currency thousands/millions
    successCss : 'alert alert-block alert-success', // CSS Class to show success message (or Positive Balance)
    errorCss : 'alert alert-block alert-error',     // CSS Class to show error message (or Negative Balance)
    pageSize : 10,                                   // Amount of items to be displayed on list views
    pageCountSize : 5,                             // Amount of pages to be displayed on the pagination
    smallPageSize : 5,                                   // Amount of items to be displayed on small table views
    maxAttendedAuctions: 3							// maximum number of simultaneous auctions
};
/**
 * API urls
 */
auction.conf.urls = {
    logout : auction.conf.urlRoot + 'logout',
    login : auction.conf.urlRoot + 'login',
    auction : auction.conf.urlRoot + 'auction',
    auctions : auction.conf.urlRoot + 'auction',
    activeAuctions : auction.conf.urlRoot + 'live/auction',
    item : auction.conf.urlRoot + 'item',
    items : auction.conf.urlRoot + 'item/auction/' + auction.conf.auctionIdUrlKey,
    purchasedItems : auction.conf.urlRoot + 'item/user/' + auction.conf.userIdUrlKey + '/purchased',
    currentItem : auction.conf.urlRoot + 'item/current/auction/' + auction.conf.auctionIdUrlKey,
    bid: auction.conf.urlRoot + 'bid',
    nextBid: auction.conf.urlRoot + 'bid/auction/' + auction.conf.auctionIdUrlKey + 
    			'/item/' + auction.conf.itemIdUrlKey + '/count/' + auction.conf.lastBidCountUrlKey,
    user: auction.conf.urlRoot + 'user',
    bidHistory : auction.conf.urlRoot + 'bid/user/' + auction.conf.userIdUrlKey,
    attendanceHistory : auction.conf.urlRoot + 'attendance/user/' + auction.conf.userIdUrlKey,
    attendanceRecord : auction.conf.urlRoot + 'attendance',
    bid : auction.conf.urlRoot + 'bid',
    myItems : auction.conf.urlRoot + 'item/auctioneer/' + auction.conf.userIdUrlKey,

};

auction.conf.tpls = {
	// General templates
	footer : auction.conf.tplRoot + 'footer.tpl',
    navbar_login : auction.conf.tplRoot + 'navbar.login.tpl',
    navbar : auction.conf.tplRoot + 'navbar.tpl',
    paginator : auction.conf.tplRoot + 'paginator.tpl',

	// Templates for the main info displays
	exploreAuctions : auction.conf.tplRoot + 'exploreAuctionsDisplay.tpl',
	userInfo : auction.conf.tplRoot + 'userInfoDisplay.tpl',
	manageAuctions : auction.conf.tplRoot + 'manageAuctionsDisplay.tpl',

	// Templates used in the attendAuctions display
    teaser : auction.conf.tplRoot + 'teaser.tpl',
	activeAuctionsSmallTable : auction.conf.tplRoot + 'activeAuctionSmallTable.tpl',
	activeAuctionsSmallTableRow : auction.conf.tplRoot + 'activeAuctionSmallTableRow.tpl',
	attendedAuction : auction.conf.tplRoot + 'attendedAuction.tpl',
	currentItemDetails : auction.conf.tplRoot + 'currentItemDetails.tpl',
	attendedAuctionDetails : auction.conf.tplRoot + 'attendedAuctionDetails.tpl',
	nextBidDetails : auction.conf.tplRoot + 'nextBidDetails.tpl',
	bidForm : auction.conf.tplRoot + 'bidForm.tpl',
	
	// Templates used in the explore Auctions display
	auctionsTable : auction.conf.tplRoot + 'auctionTable.tpl',
	auctionTableRow : auction.conf.tplRoot + 'auctionRow.tpl',
	activeAuctions : auction.conf.tplRoot + 'activeAuctionTable.tpl',
	activeAuctionTableRow : auction.conf.tplRoot + 'activeAuctionRow.tpl',
	auctionDetail: auction.conf.tplRoot + 'auctionDetail.tpl',
	itemTable: auction.conf.tplRoot + 'itemTable.tpl',
	itemRow: auction.conf.tplRoot + 'itemRow.tpl',	
	itemDetail: auction.conf.tplRoot + 'itemDetail.tpl',
	attendedAuctionDetailsSummary : auction.conf.tplRoot + 'attendedAuctionDetailsSummary.tpl',
	attendedAuctionSummary : auction.conf.tplRoot + 'attendedAuctionSummary.tpl',
	attendedAuctionSummaryButton : auction.conf.tplRoot + 'attendedAuctionSummaryButton.tpl',
	currentItemSummary : auction.conf.tplRoot + 'currentItemSummary.tpl',
	nextBidSummary : auction.conf.tplRoot + 'nextBidSummary.tpl',

	// Templates used in the ManageAuctions display
	addAuction : auction.conf.tplRoot + 'addAuction.tpl',
	myAuctions : auction.conf.tplRoot + 'myAuctions.tpl',
	editAuction : auction.conf.tplRoot + 'editAuction.tpl',
	myItemsRow : auction.conf.tplRoot + 'myItemsRow.tpl',
	myItemsTable : auction.conf.tplRoot + 'myItemsTable.tpl',
	addItem : auction.conf.tplRoot + 'addItem.tpl',
	editItem : auction.conf.tplRoot + 'editItem.tpl',

	// Templates used in the UserInfo display
	userProfile : auction.conf.tplRoot + 'userProfile.tpl',
	bidHistoryTable: auction.conf.tplRoot + 'bidHistoryTable.tpl',
	bidHistoryRow: auction.conf.tplRoot + 'bidHistoryRow.tpl',	
	attendanceHistoryTable: auction.conf.tplRoot + 'attendanceHistoryTable.tpl',
	attendanceHistoryRow: auction.conf.tplRoot + 'attendanceHistoryRow.tpl',	
	purchasedItemTable: auction.conf.tplRoot + 'purchasedItemTable.tpl',
	purchasedItemRow: auction.conf.tplRoot + 'purchasedItemRow.tpl',	
	updateProfile: auction.conf.tplRoot + 'updateProfile.tpl',	

	// Templates used in the loginDisplay
    login : auction.conf.tplRoot + 'login.tpl',
    registration : auction.conf.tplRoot + 'registration.tpl',

    profile : auction.conf.tplRoot + 'profile.tpl',
    contact : auction.conf.tplRoot + 'contact.tpl',
    warning : auction.conf.tplRoot + 'warning.tpl'
};

/**
 * Hash tags to use on the code for the different application routes of the Backbone.Router
 */
auction.conf.hash = {
    login  : '#login',
 
    // Hashes for each Navbar option
    attendAuctions: "#attendAuctions",
    exploreAuctions: "#exploreAuctions",
    manageAuctions: "#manageAuctions",
    dashboard: "#dashboard",
    userInfo: "#userInfo",

    // Hashes for attendAuctions display
    activeAuctionsSmall: "#activeAuctionsSmall/p{page}",

    // Hashes for exploreAuctionsDisplay
    allAuctions: "#allAuctions/p{page}",
    activeAuctions: "#activeAuctions/p{page}",
    searchAuctions: "#searchAuctions",
    searchItems: "#searchItems",
    itemDetail: "#itemDetail/item{itemId}",
    
    // Hashes for userInfo display
    userProfile: "#userProfile",
    editProfile: "#editProfile",
    purchaseHistory: "#purchaseHistory",
    purchaseHistoryPage: "#purchaseHistory/p{page}",
    bidHistoryPage: "#bidHistory/p{page}",
    attendanceHistoryPage: "#attendanceHistory/p{page}",
    bidHistory: "#bidHistory",
    attendanceHistory: "#attendanceHistory",
    
    // Hashes for manageAuctions display
    addAuction: "#addAuction",
    myAuctions: "#myAuctions",
    editAuction: "#editAuction",
    addItem: "#addItem",
    myItems: "#myItems",
    myItemsPage: "#myItems/p{page}",
    editItem: "#editItem",

    
    upcomingAuctions: "#upcomingAuctions/p{page}",
    auctionDetail: "#auctionDetail/auction{auctionId}/p{page}",
    itemTablePage: "#itemTablePage/p{page}",

    registration : '#registration',
    profile : '#profile',
    contact : '#contact',
    help : '#help',
    overview : '#overview',
    admin : '#admin'
};
