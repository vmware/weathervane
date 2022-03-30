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
auction.views.AuctionTableRow = Backbone.View.extend({

    /**
     * Bind the events functions to the different HTML elements
     */
    events : {
    	'click .viewAuctionDetail': 'viewAuctionDetail'
    },

    // An AuctionTableRow is a table row element
    tagName: 'tr',
    
    // Set up the template for this view
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.auctionTableRow)),
    
    /**
     * Renders the a single row of the Auction table 
     * @author Harold Rosenberg
     * @return void
     */
    render: function() {
        'use strict';
        this.$el.html(this.template(this.model.attributes));
        return this;
    },
   
    viewAuctionDetail: function() {
		auction.instances.router.navigate(
				auction.conf.hash.auctionDetail.replace(auction.conf.auctionIdUrlKey, this.model.get('id')).replace(auction.conf.pageUrlKey, 1), true);
    }
 
});



