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
 * Router class for the application:
 */

auction.Router = Backbone.Router
		.extend({
			/**
			 * Maps the functions to the urls
			 * 
			 */
			routes : {
				// Main Page
				"" : "main",
				
				// Navbar choices
				"attendAuctions" : "attendAuctions",
				"exploreAuctions" : "exploreAuctions",
				"manageAuctions" : "manageAuctions",
				"dashboard" : "dashboard",
				"userInfo" : "userInfo",

				// AttendedAuctions related
				"activeAuctionsSmall": "activeAuctionsSmallTable",
				"activeAuctionsSmall/p:page": "activeAuctionsSmallTable",

				// exploreAuctionsDisplay choices
				"activeAuctions": "activeAuctions",
				"activeAuctions/p:page": "activeAuctions",
				"searchAuctions": "searchAuctions",
				"allAuctions": "allAuctions",
				"allAuctions/p:page": "allAuctions",
				"auctionDetail": "auctionDetail",
				"auctionDetail/auction:auctionId/p:page": "auctionDetail",
				"itemTablePage": "itemTablePage",
				"itemTablePage/p:page": "itemTablePage",
				"itemDetail/item:itemId": "itemDetail",
				
				// UserInfo related
				"userProfile": "userProfile",
				"editProfile": "editProfile",
				"purchaseHistory": "purchaseHistory",
				"purchaseHistory/p:page": "purchaseHistory",
				"bidHistory": "bidHistory",
				"attendanceHistory": "attendanceHistory",
				"bidHistory/p:page": "bidHistory",
				"attendanceHistory/p:page": "attendanceHistory",
				
				// manageAuctions related
				"addAuction" : "addAuction",
				"myAuctions" : "myAuctions",
				"myAuctions/p:page" : "myAuctions",
				"editAuction" : "editAuction",
				"addItem" : "addItem",
				"myItems" : "myItems",
				"myItems/p:page" : "myItems",
				"editItem" : "editItem",
				
				// Login Page
				"login/:error" : "login",
				"login" : "login",
				"registration" : "registration",

				// Others
				"contact" : "contact"
			},

			initialize : function() {
				'use strict';
				
				// Create the models that will be used to hold the data for each area of the UI
				auction.instances.activeAuctionSmallTableCollection = new auction.models.ActiveAuctions({page: 0});
				
				// Initialize arrays for models and views related to attended auctions
				auction.instances.attendedAuctionIds = new Array();
				
				auction.instances.joinAuctionModels = new Array();
				auction.instances.attendedAuctionViews = new Array();
				auction.instances.attendedAuctionSummaryViews = new Array();

				auction.instances.attendedAuctionDetailsModel = new Array();
				auction.instances.attendedAuctionDetailsView = new Array();
				auction.instances.attendedAuctionDetailsSummaryView = new Array();

				auction.instances.attendedAuctionIds = new Array();
				
				auction.instances.currentItemModels = new Array();
				auction.instances.currentItemViews = new Array();
				auction.instances.nextBidModels = new Array();
				auction.instances.nextBidViews = new Array();
				auction.instances.postBidModels = new Array();
				auction.instances.postBidViews = new Array();

				auction.instances.currentItemSummaryViews = new Array();
				auction.instances.nextBidSummaryViews = new Array();

				// Initialize models, views, and a holder of available indexes at which to place attended auctions
				for (var i=auction.conf.maxAttendedAuctions; i >0 ; i--) {
					auction.instances.attendedAuctionIds.push(i);

					auction.instances.joinAuctionModels[i] = new auction.models.JoinAuction;
					auction.instances.attendedAuctionViews[i] = new auction.views.AttendedAuction({
			    		model: auction.instances.joinAuctionModels[i], 
			    		el: "#attendedAuction" + i, 
			    		divId: i 
			    		});
					auction.instances.attendedAuctionSummaryViews[i] = new auction.views.AttendedAuctionSummary({
			    		model: auction.instances.joinAuctionModels[i], 
			    		el: "#attendedAuctionSummary" + i, 
			    		divId: i 
			    		});
					
					auction.instances.attendedAuctionDetailsModel[i] = new auction.models.Auction;
					auction.instances.attendedAuctionDetailsView[i] = new auction.views.AttendedAuctionDetails({
			    		model: auction.instances.attendedAuctionDetailsModel[i], 
			    		el: "#attendedAuctionDetails" + i, 
			    		divId: i
			        });
					auction.instances.attendedAuctionDetailsSummaryView[i] = new auction.views.AttendedAuctionDetailsSummary({
			    		model: auction.instances.attendedAuctionDetailsModel[i], 
			    		el: "#attendedAuctionDetailsSummary" + i, 
			    		divId: i
			        });
					
					auction.instances.currentItemModels[i] = new auction.models.CurrentItem;
					auction.instances.currentItemViews[i] = new auction.views.CurrentItem({
			    		model: auction.instances.currentItemModels[i], 
			    		el: "#currentItemDetails" + i, 
			    		divId: i
			        });
					auction.instances.currentItemSummaryViews[i] = new auction.views.CurrentItemSummary({
			    		model: auction.instances.currentItemModels[i], 
			    		el: "#currentItemSummary" + i, 
			    		divId: i
			        });
					
					auction.instances.nextBidModels[i] = new auction.models.NextBid;
					auction.instances.nextBidViews[i] = new auction.views.NextBid({
			    		model: auction.instances.nextBidModels[i], 
			    		el: "#currentBidDetails" + i, 
			    		divId: i
			        });
					auction.instances.nextBidSummaryViews[i] = new auction.views.NextBidSummary({
			    		model: auction.instances.nextBidModels[i], 
			    		el: "#currentBidSummary" + i, 
			    		divId: i
			        });
					
					auction.instances.postBidModels[i] = new auction.models.Bid;
					auction.instances.postBidViews[i] = new auction.views.PostBid({
			    		model: auction.instances.postBidModels[i], 
			    		el: "#bidForm" + i, 
			    		divId: i
			        });
				}				
				
				// Create instances of the views that are associated with specific models
				auction.instances.activeAuctionSmallTable = new auction.views.ActiveAuctionSmallTable({
					el : '#attendedAuctionDisplay #activeAuctionSmallTable',
					collection: auction.instances.activeAuctionSmallTableCollection
				});				
				
				// Create the views for areas of the UI that have no model	
				auction.instances.exploreAuctions = new auction.views.ExploreAuctions(
						{
							el : '#exploreAuctionsDisplay'
						});

				auction.instances.userInfo = new auction.views.UserInfo(
						{
							el : '#userInfoDisplay'
						});

				auction.instances.manageAuctions = new auction.views.ManageAuctions(
						{
							el : '#manageAuctionsDisplay'
						});

				auction.instances.navbarBottomHalf = new auction.views.NavbarBottomHalf(
						{
							el : '#navbarBottomHalf'
						});

				auction.instances.attendedAuctionSummaryButton = new auction.views.AttendedAuctionSummaryButton(
						{
							el : '#attendedAuctionSummaryButton'
						});

				auction.instances.navbar = new auction.views.Navbar({
					el : '#mainNavbar'
				});
				auction.instances.footer = new auction.views.Footer({
					el : '#nc-footer'
				});
				auction.instances.teaser = new auction.views.Teaser({
					el : '#teaserDiv'
				});
				auction.instances.login = new auction.views.Login({
					el : '#nc-login'
				});
				auction.instances.registration = new auction.views.Registration(
						{
							el : '#nc-registration'
						});
				
				$('#attendedAuction1').empty();
				$('#attendedAuction2').empty();
				$('#attendedAuction3').empty();
				if (!auction.utils.loggedIn()) {
					// Clear out the cookie used to keep track of already attended auctions
					var auctions = {
							attended: []
					}
					$.cookie( auction.conf.auctionCookieName, auctions);
				} else {
					// Re-render any attended auctions
					var auctionList = auction.utils.getAttendedAuctions().attended;
					while (auctionList.length > 0) {
						var attendedAuctionDivId = auction.instances.attendedAuctionIds.pop();

						var auctionId = auctionList.pop();	
				    	auction.instances.joinAuctionModels[attendedAuctionDivId].clear({silent: true});
						auction.instances.joinAuctionModels[attendedAuctionDivId].set({
								"auctionId": auctionId, 
								"userId": auction.session.userid
							});
						auction.instances.joinAuctionModels[attendedAuctionDivId].save({error: function() {
							    auction.instances.attendedAuctionIds.push(attendedAuctionDivId);
						}});
					}

				}
				
				// Navigate to the main page
				this.navigate(auction.conf.hash.attendAuctions, true);
				
			},
			
			main : function() {
				'use strict';

				// Render the main page if logged in or the Login otherwise
				if (!auction.utils.loggedIn()) {
					auction.instances.router.navigate(auction.conf.hash.login, true);
				}
			},

			
			attendAuctions : function() {
				'use strict';

				// Render the main page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.navbar.render();
					auction.instances.attendedAuctionSummaryButton.render();
					auction.utils.showAttendedAuctionDisplay();
					auction.instances.teaser.render();
					auction.instances.footer.render();
					auction.instances.activeAuctionSmallTableCollection.fetch({data: {page:0, pageSize: auction.conf.smallPageSize}});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}
			},

			exploreAuctions : function() {
				'use strict';

				// Render the page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.exploreAuctions.render();
					auction.instances.exploreAuctions.activeAuctions({page:0, pageSize: auction.conf.pageSize});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}
			},

			dashboard : function() {
				'use strict';

				// Render the page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.utils.showDashboardDisplay();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}
			},

			userInfo : function() {
				'use strict';

				// Render the page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.userInfo.render();
					auction.instances.userInfo.userProfile();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}
			},

			manageAuctions : function() {
				'use strict';

				// Render the page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.render();
					auction.instances.manageAuctions.addItem();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}
			},

			
			allAuctions: function(page) {
				if (!page) page = 1;
				// Render the main page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.exploreAuctions.allAuctions({page:page-1, pageSize: auction.conf.pageSize});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			activeAuctions: function(page) {
				if (!page) page = 1;
				// Render the main page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.exploreAuctions.activeAuctions({page:page-1, pageSize: auction.conf.pageSize});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			auctionDetail: function (auctionId, page) {
				if (!page) page = 1;

				// Render the main page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.exploreAuctions.auctionDetail({auctionId: auctionId, pageInfo: {page:page-1, pageSize: auction.conf.pageSize}});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			itemTablePage: function (page) {
				if (!page) page = 1;

				if (auction.utils.loggedIn()) {
					auction.instances.exploreAuctions.itemTablePage({page:page-1, pageSize: auction.conf.pageSize});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			itemDetail: function (itemId) {

				// Render the main page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.exploreAuctions.itemDetail({itemId: itemId});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			activeAuctionsSmallTable: function(page) {
				if (!page) page = 1;
				// Render the main page if logged in or the Login otherwise
				if (auction.utils.loggedIn()) {

					auction.instances.activeAuctionSmallTableCollection.fetch({data: {page:page-1, pageSize: auction.conf.smallPageSize},
	                    error : auction.utils.onApiError});

				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			addAuction: function() {

				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.addAuction();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			myAuctions: function() {

				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.myAuctions();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			editAuction: function() {

				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.editAuction();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			addItem: function() {

				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.addItem();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			myItems: function(page) {
				if (!page) page = 1;

				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.myItems({pageInfo: {page:page-1, pageSize: auction.conf.pageSize}});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			editItem: function() {

				if (auction.utils.loggedIn()) {
					auction.instances.manageAuctions.editItem();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			userProfile: function() {

				// Render the main page if logged in or the userProfile otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.userInfo.userProfile();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},
			
			editProfile: function() {

				// Render the main page if logged in or the editProfile otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.userInfo.editProfile();
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			purchaseHistory: function(page) {
				if (!page) page = 1;

				// Render the main page if logged in or the userProfile otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.userInfo.purchaseHistory({pageInfo: {page:page-1, pageSize: auction.conf.pageSize}});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			bidHistory: function(page) {
				if (!page) page = 1;

				// Render the main page if logged in or the userProfile otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.userInfo.bidHistory({pageInfo: {page:page-1, pageSize: auction.conf.pageSize}});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			attendanceHistory: function(page) {
				if (!page) page = 1;

				// Render the main page if logged in or the userProfile otherwise
				if (auction.utils.loggedIn()) {
					auction.instances.userInfo.attendanceHistory({pageInfo: {page:page-1, pageSize: auction.conf.pageSize}});
				} else {
					auction.instances.router.navigate(
							auction.conf.hash.login, true);
				}

			},

			login : function(error) {
				'use strict';
				if (auction.utils.loggedIn()) {
					auction.instances.router.navigate(
							auction.conf.hash.attendAuctions, true);
				} else {
					auction.instances.login.render(error);
					auction.instances.navbar.renderLogin();
					auction.utils.showLoginDisplay();
				}
				auction.instances.footer.render();
			},

			registration : function(error) {
				'use strict';
				if (auction.utils.loggedIn()) {
					auction.instances.router.navigate(
							auction.conf.hash.main, true);
				} else {
					auction.instances.login.render(error);
					auction.instances.navbar.renderLogin();
					auction.utils.showLoginDisplay();
					auction.containers.login.hide();
					auction.instances.registration.render(error);
				}
				auction.instances.footer.render();
			},

			contact : function() {
				'use strict';
				var contact = new auction.models.Contact();
				contact
						.fetch({
							success : function() {
								var jsonObj = contact.toJSON();
								if (navigator.geolocation) {
									navigator.geolocation
											.getCurrentPosition(
													function(position) {
														var minDistance = Number.POSITIVE_INFINITY, nearestOffice, i, distance;
														for (i = 0; i < jsonObj.locations.length; i++) {
															distance = auction.utils
																	.calculateDistance(
																			position.coords.latitude,
																			jsonObj.locations[i].latitude,
																			position.coords.longitude,
																			jsonObj.locations[i].longitude);
															if (minDistance > distance) {
																minDistance = distance;
																nearestOffice = jsonObj.locations[i].address;
															}
														}
														auction.strings.location = nearestOffice;
														auction.instances.contact
																.render();
													},
													function(error) {
														auction.instances.contact
																.render();
													});
								} else {
									auction.instances.contact.render();
								}
							},
							error : function() {
								auction.instances.contact.render();
							}
						});
				if (auction.utils.loggedIn()) {
					auction.utils.hideAll();
					auction.instances.navbar.render();
				} else {
					auction.utils.hideAll();
					auction.instances.navbar.renderLogin();
				}
				auction.instances.footer.render();
			}
		});

$(function() {
	
	auction.instances.router = new auction.Router();

	Backbone.history.start();
	$.support.cors = true;
});
