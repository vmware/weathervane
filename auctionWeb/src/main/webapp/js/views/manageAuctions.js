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
auction.views.ManageAuctions = Backbone.View.extend({

			/**
			 * Bind the events functions to the different HTML elements
			 */
			events : {
				'click #addAuctionLink' : 'addAuctionsDispatch',
				'click #myAuctionsLink' : 'myAuctionsDispatch',
				'click #addItemLink' : 'addItemDispatch',
				'click #myItemsLink' : 'myItemsDispatch'
			},

			initialize : function(options) {
				'use strict';
				auction.containers.manageAuctions = this.$el;
			},

			render : function(model) {
				'use strict';
				var manageAuctions = _.template(
						auction.utils
								.getTemplate(auction.conf.tpls.manageAuctions))();
				this.$el.html(manageAuctions);

				// The model and view for the userProfile
				auction.instances.addItemModel = new auction.models.Item();
				auction.instances.addItemView = new auction.views.AddItem(
						{
							el : '#addItem',
							model : auction.instances.addItemModel
						});
				auction.instances.editItemView = new auction.views.EditItem(
						{
							el : '#editItem',
							model : auction.instances.addItemModel
						});
				
				auction.instances.myItemsCollection = new auction.models.MyItems(
						{
							page : 0
						});
				auction.instances.myItemsView = new auction.views.MyItemsTable(
						{
							el : '#myItems',
							collection : auction.instances.myItemsCollection
						});



			},

			/*
			 * Dispatch through router rather than calling activeAuctions()
			 * directly in order to have browser history and back/forward work
			 * properly
			 */
			addItemDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.addItem, true);
			},

			addItem : function() {

				if (!auction.instances.addItemModel) {
					auction.instances.manageAuctions.render();
				}
				auction.utils.showManageAuctionsDisplay({hash: auction.conf.hash.addItem});

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.addItemModel.clear({
					silent : true
				});
				auction.instances.addItemView.render();
			},
			
			editItemDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.editItem, true);
			},

			editItem : function() {

				if (!auction.instances.addItemModel) {
					auction.instances.manageAuctions.render();
				}
				auction.utils.showManageAuctionsDisplay({hash: auction.conf.hash.editItem});

				auction.instances.editItemView.render();
			},
			
			myItemsDispatch : function() {
				auction.instances.router.navigate(
						auction.conf.hash.myItems, true);
			},

			myItems : function(data) {
		    	var page = data.pageInfo.page;
		    	var pageSize = data.pageInfo.pageSize;
		    	this.pageSize = pageSize;

				if (!auction.instances.myItemsCollection) {
					auction.instances.manageAuctions.render();
				}
				auction.utils.showManageAuctionsDisplay({hash: auction.conf.hash.myItems});

				var session = $.cookie(auction.conf.sessionCookieName)
				auction.instances.myItemsCollection.userId = session.userid;

				auction.instances.myItemsCollection.fetch({data: {page:page, pageSize: pageSize}});
			},



		});