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
 * View Class for the CurrentItem part of an
 * attended auction display
 * @author Hal Rosenberg
 */
auction.views.CurrentItem = Backbone.View.extend({
    
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.currentItemDetails)),

    /**
     * Bind the events functions to the different HTML elements
     */
    events : {
  		'click .itemDetail' : 'itemDetail'
    },
    
    initialize : function(options) {
    	this.divId = options.divId;
        this.model.on('sync', this.render, this);
    },
    
    /**
     * Renders the current Item View
     * @author Harold Rosenberg
     * @return void
     */
    render: function() {
        'use strict';
   
        // Create the model and view for the post Bid form
        this.$el.empty();
                        
        // If it hasn't been rendered yet, build the section and store the key dom objects
        this.$el.html(this.template(this.model.attributes));   
        
        // Check whether there are images for this item.  If so, add a thumbnail 
        // for the first image to the currentItemImage div in this area
        var links = this.model.get("links");
        if (links != null) {
        	if ('ItemImage' in links) {
        		var firstImageLinks = links.ItemImage[0];
        		if ('READ' in firstImageLinks) {
        			this.$('.currentItemImage').append('<img src="' + auction.conf.urlRoot + firstImageLinks.READ + '?size=THUMBNAIL" />');
        		}
        	}
        }
        
        // Create the model and view for the next bid and fetch it
        auction.instances.nextBidModels[this.divId].clear({silent: true});
        auction.instances.nextBidModels[this.divId].set({"auctionId": this.model.get("auctionId"), 
        	"itemId": this.model.get("id"), "lastBidCount": 0}, {silent: true});
        auction.instances.nextBidModels[this.divId].fetch();

        auction.instances.postBidModels[this.divId].clear({silent: true});
        auction.instances.postBidModels[this.divId].set({"auctionId": this.model.get("auctionId"), "itemId": this.model.get("id"), "message": "BIDNOW", "amount": 0}, {silent: true});
        auction.instances.postBidViews[this.divId].render();
        
        this.$el.show();
		
        return this;
    },

  	itemDetail : function() {

  		var itemId = this.model.get("id");

  		auction.instances.router.navigate(
  				auction.conf.hash.itemDetail.replace(auction.conf.itemIdUrlKey, itemId), true);
  	}

       
});



