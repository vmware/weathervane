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
 * View Class for the NextBid part of an
 * attended auction display
 * @author Hal Rosenberg
 */
auction.views.NextBid = Backbone.View.extend({
    
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.nextBidDetails)),

    initialize : function(options) {
    	this.divId = options.divId;
        this.model.on('sync', this.render, this);
    },
    
    /**
     * Renders the next bid View
     * @author Harold Rosenberg
     * @return void
     */
    render: function() {
        'use strict';
   
        // If the user has left the auction then we need to stop getting
        // new bids.  Can tell that this has happened if neither this view
        // or the associated summary view is visible
        var summaryView = auction.instances.attendedAuctionDetailsSummaryView[this.divId];
        if (!(this.$el.is(':visible') || summaryView.$el.is(':visible'))) {
        	return;
        }
        
        // get the next bid
        var biddingState = this.model.get("biddingState");
        if (auction.instances.nextBidModels[this.divId] != null) {
        	if ((biddingState === "OPEN") || (biddingState === "LASTCALL") || (biddingState === "INFO")){        		        		
        		// Get the next bid (long pull)
            	this.model.fetch();
        	} else if (biddingState === "SOLD") {
        		// Get the next item to be sold
        		auction.instances.currentItemModels[this.divId].fetch();
        	}
        }
                
        this.$el.empty();

        biddingState = this.model.get("biddingState");
    	this.model.set({biddingMessage: biddingState});
        if (auction.instances.nextBidModels[this.divId] != null) {
        	if ((biddingState === "OPEN") || (biddingState === "LASTCALL") || (biddingState === "INFO")){
                if (this.model.get("userId") === auction.session.userid) {
                	this.model.set({biddingMessage: "HIGHBIDDER"});
                }
        	} else if (biddingState === "SOLD") {
                if (this.model.get("userId") === auction.session.userid) {
                	this.model.set({biddingMessage: "WINNINGBIDDER"});
                }
        	}
        }

        var tmplVars = _.clone(this.model.attributes);
        tmplVars["divId"] = this.divId;

        this.$el.html(this.template(tmplVars));   

        // Color the bid area according to the bidding state
        if (auction.instances.nextBidModels[this.divId] != null) {
        	if ((biddingState === "OPEN") || (biddingState === "LASTCALL") || (biddingState === "INFO")){
        		if (biddingState === "OPEN") {
        			$(".nextBidRow" + this.divId).removeClass("LASTCALL");
        			$(".nextBidRow" + this.divId).removeClass("SOLD");
        			$(".nextBidRow" + this.divId).addClass("OPEN");
        		} else if (biddingState === "LASTCALL") {
        			$(".nextBidRow" + this.divId).removeClass("OPEN");
        			$(".nextBidRow" + this.divId).addClass("LASTCALL");
        			$(".nextBidRow" + this.divId).removeClass("SOLD");
        		} 
        	} else if (biddingState === "SOLD") {
        		$(".nextBidRow" + this.divId).removeClass("OPEN");
        		$(".nextBidRow" + this.divId).removeClass("LASTCALL");
        		$(".nextBidRow" + this.divId).addClass("SOLD").delay(2000);
        	}
        }

        this.$el.show();

        return this;
    }
       
});



