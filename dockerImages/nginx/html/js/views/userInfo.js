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
 * View Class for the UserInfo Display
 * 
 * @author Hal Rosenberg
 */
auction.views.UserInfo = Backbone.View.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {
				'click #userProfileLink' : 'userProfileDispatch',
				'click #editProfileLink' : 'editProfileDispatch',
				'click #purchaseHistoryLink' : 'purchaseHistoryDispatch',
				'click #bidHistoryLink' : 'bidHistoryDispatch',
				'click #attendanceHistorySelect' : 'attendanceHistoryDispatch'
			},

			initialize : function(options) {
				'use strict';
				auction.containers.userInfo = this.$el;
			},

			render : function(model) {
				'use strict';
				var userInfo = _.template(
						auction.utils
								.getTemplate(auction.conf.tpls.userInfo))();
				this.$el.html(userInfo);

				// The model and view for the userProfile
				auction.instances.userProfileModel = new auction.models.User();
				auction.instances.userProfileView = new auction.views.UserProfile(
						{
							el : '#userProfile',
							model : auction.instances.userProfileModel
						});

				auction.instances.purchasedItemsCollection = new auction.models.PurchasedItems(
						{
							page : 0
						});
				auction.instances.purchasedItemsView = new auction.views.PurchasedItemsTable(
						{
							el : '#purchaseHistory',
							collection : auction.instances.purchasedItemsCollection
						});

				auction.instances.bidHistoryCollection = new auction.models.BidHistory(
						{
							page : 0
						});
				auction.instances.bidHistoryView = new auction.views.BidHistoryTable(
						{
							el : '#bidHistory',
							collection : auction.instances.bidHistoryCollection
						});

				auction.instances.attendanceHistoryCollection = new auction.models.AttendanceHistory(
						{
							page : 0
						});
				auction.instances.attendanceHistoryView = new auction.views.AttendanceHistoryTable(
						{
							el : '#attendanceHistory',
							collection : auction.instances.attendanceHistoryCollection
						});

				auction.instances.updateProfileModel = new auction.models.User();
				auction.instances.updateProfileView = new auction.views.UpdateProfile(
						{
							el : '#editProfile',
							model : auction.instances.updateProfileModel
						});
			},

			/*
			 * Dispatch through router rather than calling activeAuctions()
			 * directly in order to have browser history and back/forward work
			 * properly
			 */
			userProfileDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.userProfile, true);
			},

			userProfile : function() {

				if (!auction.instances.userProfileModel) {
					auction.instances.userInfo.render();
				}
				auction.utils.showUserProfile();

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.userProfileModel.clear({
					silent : true
				});
				auction.instances.userProfileModel.set({
					id : session.userid
				});
				auction.instances.userProfileModel.fetch({
					error : auction.utils.onApiError
				});
			},

			editProfileDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.editProfile, true);
			},

			editProfile : function() {

				if (!auction.instances.updateProfileModel) {
					auction.instances.userInfo.render();
				}
				auction.utils.showUpdateProfile();

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.updateProfileModel.clear({
					silent : true
				});
				auction.instances.updateProfileModel.set({
					id : session.userid
				});
				auction.instances.updateProfileModel.fetch({
					error : auction.utils.onApiError
				});
			},

			purchaseHistoryDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.purchaseHistory, true);
			},

			purchaseHistory : function(data) {
		    	var page = data.pageInfo.page;
		    	var pageSize = data.pageInfo.pageSize;
		    	this.pageSize = pageSize;

				if (!auction.instances.purchasedItemsCollection) {
					auction.instances.userInfo.render();
				}
				auction.utils.showPurchaseHistory();

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.purchasedItemsCollection.userId = session.userid;

				auction.instances.purchasedItemsCollection.fetch({data: {page:page, pageSize: pageSize}});
			},

			bidHistoryDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.bidHistory, true);
			},

			bidHistory : function(data) {
		    	var page = data.pageInfo.page;
		    	var pageSize = data.pageInfo.pageSize;
		    	this.pageSize = pageSize;

				if (!auction.instances.bidHistoryCollection) {
					auction.instances.userInfo.render();
				}
				auction.utils.showBidHistory();

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.bidHistoryCollection.userId = session.userid;

				auction.instances.bidHistoryCollection.fetch({data: {page:page, pageSize: pageSize}});
			},

			attendanceHistoryDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.attendanceHistory, true);
			},

			attendanceHistory : function(data) {
		    	var page = data.pageInfo.page;
		    	var pageSize = data.pageInfo.pageSize;
		    	this.pageSize = pageSize;

				if (!auction.instances.attendanceHistoryCollection) {
					auction.instances.userInfo.render();
				}
				auction.utils.showAttendanceHistory();

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.attendanceHistoryCollection.userId = session.userid;

				auction.instances.attendanceHistoryCollection.fetch({data: {page:page, pageSize: pageSize}});
			}
			


		});