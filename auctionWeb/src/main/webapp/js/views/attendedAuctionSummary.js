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
 * View Class for an attended Auction
 * @author Hal Rosenberg
 */
auction.views.AttendedAuctionSummary = Backbone.View.extend({
    
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.attendedAuctionSummary)),

    initialize : function(options) {
    	this.divId = options.divId;
        this.model.on('change:id', this.render, this);
    },
    
    events: {
    },
        
    /**
     * Renders the Attend Auction View
     * @author Harold Rosenberg
     * @return void
     */
    render: function() {
        'use strict';

        this.$el.empty();
                
        this.$el.html(this.template({divId: this.divId}));  
        this.$el.show();

		auction.instances.currentItemSummaryViews[this.divId].setElement("#currentItemSummary" + this.divId);
		auction.instances.nextBidSummaryViews[this.divId].setElement("#currentBidSummary" + this.divId);
		auction.instances.attendedAuctionDetailsSummaryView[this.divId].setElement("#attendedAuctionDetailsSummary" + this.divId);

        return this;
    },
    
    leaveAuction: function() {
    	
    	// Hide this display
    	this.$el.empty();
    	this.$el.hide();
    	
    }
       
});



