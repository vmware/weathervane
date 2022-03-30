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
auction.views.AttendedAuction = Backbone.View.extend({
    
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.attendedAuction)),

    initialize : function(options) {
    	this.divId = options.divId;
        this.model.on('change:id', this.render, this);
    },
    
    events: {
        'click .leaveAuctionButton' : 'leaveAuction',
        'click .attendedAuctionDetailsButton' : 'viewAuctionDetail'
    },
        
    /**
     * Renders the Attend Auction View
     * @author Harold Rosenberg
     * @return void
     */
    render: function() {
        'use strict';
    	this.auctionModel = auction.instances.attendedAuctionDetailsModel[this.divId];

        this.$el.empty();
                
        // If it hasn't been rendered yet, build the section and store the key dom objects
        $('#attendedAuctionTeaser').hide();
        $('#attendedAuctions').show();        

        this.$el.html(this.template({divId: this.divId}));  
        this.$el.show();

		auction.instances.attendedAuctionDetailsView[this.divId].setElement("#attendedAuctionDetails" + this.divId);
		auction.instances.currentItemViews[this.divId].setElement("#currentItemDetails" + this.divId);
		auction.instances.nextBidViews[this.divId].setElement("#currentBidDetails" + this.divId);
		auction.instances.postBidViews[this.divId].setElement("#bidForm" + this.divId);

        // Create the model and view for the Current Item and fetch it
        auction.instances.attendedAuctionDetailsModel[this.divId].clear({silent: true})
        auction.instances.attendedAuctionDetailsModel[this.divId].set({"id": this.model.get("auctionId")});
        auction.instances.attendedAuctionDetailsModel[this.divId].fetch();

        auction.instances.currentItemModels[this.divId].clear({silent: true})
        auction.instances.currentItemModels[this.divId].set({"auctionId": this.model.get("auctionId"), "id": 0}, {silent: true});
        auction.instances.currentItemModels[this.divId].fetch();

        return this;
    },
    
    leaveAuction: function(event) {
    	
    	if (!auction.utils.removeAttendedAuction(this.auctionModel.get("id"))) {
    		alert("You are not attending Auction " + this.auctionModel.get("id"));
    		return;
    	}

    	// Hide the summary display that is shadowing this one
    	auction.instances.attendedAuctionSummaryViews[this.divId].leaveAuction();
    	
    	// Hide this display
    	this.$el.empty();
    	this.$el.hide();
    	
    	// Keep track of the fact that this spot is available for 
    	auction.instances.attendedAuctionIds.push(this.divId);
    	
    	if (auction.instances.attendedAuctionIds.length == auction.conf.maxAttendedAuctions) {
            $('#attendedAuctions').hide();
            $('#attendedAuctionTeaser').show();
    	}

    }, 
    
    viewAuctionDetail: function() {
		auction.instances.router.navigate(
				auction.conf.hash.auctionDetail.replace(auction.conf.auctionIdUrlKey, this.auctionModel.get('id')).replace(auction.conf.pageUrlKey, 1), true);
    }
 

    
       
});



