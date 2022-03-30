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
auction.views.PurchasedItemRow = Backbone.View.extend({

    /**
     * Bind the events functions to the different HTML elements
     */
    events : {
  		'click .itemDetail' : 'itemDetail'
    },

    // An itemRow is a table row element
    tagName: 'tr',
    
    // Set up the template for this view
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.purchasedItemRow)),
    
    /**
     * Renders the a single row of the Auction table 
     * @author Harold Rosenberg
     * @return void
     */
    render: function() {
        'use strict';
        this.$el.html(this.template(this.model.attributes));
        
        // Check whether there are images for this item.  If so, add a thumbnail 
        // for the first image to the itemImage td in this area
        var links = this.model.get("links");
        if (links != null) {
        	if ('ItemImage' in links) {
        		var firstImageLinks = links.ItemImage[0];
        		if ('READ' in firstImageLinks) {
      			  this.$('.itemImage').append('<img src="' + auction.conf.urlRoot + firstImageLinks.READ + '?size=THUMBNAIL" />');
        		}
        	}
        }

        return this;
    },
    
  	itemDetail : function() {

  		var itemId = this.model.get("id");

  		auction.instances.router.navigate(
  				auction.conf.hash.itemDetail.replace(auction.conf.itemIdUrlKey, itemId), true);
  	}
   
});



