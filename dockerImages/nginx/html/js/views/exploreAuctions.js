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
 * View Class for the ExploreAuctions Display
 * @author Hal Rosenberg
 */
auction.views.ExploreAuctions = Backbone.View.extend({

	/**
     * Bind the events functions to the different HTML elements
     */
    events: {
        'click #activeAuctionsLink': 'activeAuctionsDispatch',
        'click #searchAuctionsLink': 'searchAuctionsDispatch',
        'click #searchItemsLink': 'searchItemsDispatch',
        'click #allAuctionsLink': 'allAuctionsDispatch'
    },

    initialize: function (options) {
        'use strict';
        auction.containers.exploreAuctions = this.$el;

    },

    render: function (model) {
        'use strict';
        var exploreAuctions = _.template(auction.utils.getTemplate(auction.conf.tpls.exploreAuctions))();
        this.$el.html(exploreAuctions);
        
        // The model and view for the activeAuctionTable
		this.activeAuctionTableCollection = new auction.models.ActiveAuctions({page: 0});
		this.activeAuctionTable = new auction.views.ActiveAuctionTable({
			el : '#activeAuctionTable',
			collection: this.activeAuctionTableCollection
		});

		this.auctionTableCollection = new auction.models.Auctions({page: 0});
		this.auctionTable = new auction.views.AuctionTable({
			el : '#auctionTable', 
			collection: this.auctionTableCollection
		});
		
		// Models and views for Auction Detail
		this.auctionDetailModel = new auction.models.Auction();
		this.itemTableCollection = new auction.models.Items({page: 0});
		auction.instances.auctionDetail = new auction.views.AuctionDetail({
			el : '#auctionDetailInfo',
			model: this.auctionDetailModel
		});
		auction.instances.itemTable = new auction.views.ItemTable({
			el : '#itemTable',
			collection: this.itemTableCollection
		});
		
		// Models and views for Item Detail
		this.itemDetailModel = new auction.models.Item();
		auction.instances.itemDetail = new auction.views.ItemDetail({
			el : '#itemDetail',
			model: this.itemDetailModel
		});
    },
        
    /*
     * Dispatch through router rather than calling activeAuctions() directly in order to
     * have browser history and back/forward work properly
     */
    activeAuctionsDispatch: function() {
    	var finalHash = auction.conf.hash.activeAuctions.replace(auction.conf.pageUrlKey, 1);
    	auction.instances.router.navigate(finalHash, true);
    },
    
    activeAuctions: function(pageInfo) {
    	var page = pageInfo.page;
    	var pageSize = pageInfo.pageSize;
    	
    	if (!this.activeAuctionTableCollection) {
    		this.render();
    	}
    	
		auction.utils.showActiveAuctionsTable();
		this.activeAuctionTableCollection.fetch({data: {page:page, pageSize: pageSize},
            error : auction.utils.onApiError});
    },
    
    /*
     * Dispatch through router rather than calling auctionDetail() directly in order to
     * have browser history and back/forward work properly
     */
    auctionDetailDispatch: function() {
    	auction.instances.router.navigate(auction.conf.hash.auctionDetail, true);
    },
    
    auctionDetail: function(data) {
    	var page = data.pageInfo.page;
    	var pageSize = data.pageInfo.pageSize;
    	this.pageSize = pageSize;
    	var auctionId = data.auctionId;
    	
    	if (!this.itemTableCollection) {
    		this.render();
    	}
    	
    	auction.utils.showAuctionDetail();

		this.itemTableCollection.auctionId = auctionId;
		this.itemTableCollection.fetch({data: {page:page, pageSize: pageSize}});

		this.auctionDetailModel.id =  auctionId;
		this.auctionDetailModel.fetch();
    	
    },
    
    itemTablePage: function(pageInfo) {
    	var page = pageInfo.page;
    	var pageSize = pageInfo.pageSize;

		this.itemTableCollection.fetch({data: {page:page, pageSize: pageSize}});    	
    },
    
    /*
     * Dispatch through router rather than calling searchAuctions() directly in order to
     * have browser history and back/forward work properly
     */
    searchAuctionsDispatch: function() {
    	auction.instances.router.navigate(auction.conf.hash.searchAuctions, true);
    },
    
    searchAuctions: function() {
    	
    },
    
    /*
     * Dispatch through router rather than calling searchItems() directly in order to
     * have browser history and back/forward work properly
     */
    searchItemsDispatch: function() {
    	auction.instances.router.navigate(auction.conf.hash.searchItems, true);
    },
    
    searchItems: function() {
    	
    },
    
    /*
     * Dispatch through router rather than calling allAuctions() directly in order to
     * have browser history and back/forward work properly
     */
    allAuctionsDispatch: function() {
    	var finalHash = auction.conf.hash.allAuctions.replace(auction.conf.pageUrlKey, 1);
    	auction.instances.router.navigate(finalHash, true);
    },
    
    allAuctions: function(pageInfo) {
    	var page = pageInfo.page;
    	var pageSize = pageInfo.pageSize;

    	if (!this.auctionTableCollection) {
    		this.render();
    	}    	

		auction.utils.showAllAuctionsTable();
    	this.auctionTableCollection.fetch({data: {page:page, pageSize: auction.conf.pageSize},
            error : auction.utils.onApiError});

    },
    
    /*
     * Dispatch through router rather than calling itemDetail() directly in order to
     * have browser history and back/forward work properly
     */
    itemDetailDispatch: function() {
    	auction.instances.router.navigate(auction.conf.hash.itemDetail, true);
    },
    
    itemDetail: function(data) {
    	var itemId = data.itemId;
    	
    	if (!this.itemDetailModel) {
    		this.render();
    	}
    	
    	auction.utils.showItemDetail();

    	this.itemDetailModel.clear({silent:true});
    	this.itemDetailModel.set({id: itemId}, {silent: true});
    	this.itemDetailModel.fetch();
    	
    },
        
});