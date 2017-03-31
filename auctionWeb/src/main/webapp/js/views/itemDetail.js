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
 * View Class for Item details
 */
auction.views.ItemDetail = Backbone.View.extend({

    /**
     * Bind the events functions to the different HTML elements
     */
    events : {
    },
    
    initialize : function(options) {
        this.model.on('change:name', this.render, this);
    },
    
    // Set up the template for this view
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.itemDetail)),
    
    /**
     * Renders the a single row of the Auction table 
     * @author Harold Rosenberg (hrosenbe@vmware.com)
     * @return void
     */
    render: function() {
        'use strict';
				var purchaseDate = "Not Sold";
				if (this.model.get("biddingEndTime") != null) {
					purchaseDate = new Date(this.model.get("biddingEndTime"));
					purchaseDate = purchaseDate.toDateString();
				}
				this.model.set({ purchaseDate: purchaseDate});
        
        var finalTemplate = this.template(this.model.attributes);
        this.$el.html(finalTemplate);

        // Check whether there are images for this item.  If so, add a preview 
        // for all images
        var links = this.model.get("links");
        if (links != null) {
        	if ('ItemImage' in links) {
        		var itemImageLinks = links.ItemImage;
        		for (var imageNum=0; imageNum < itemImageLinks.length; imageNum++) {
        			var imageLinks = links.ItemImage[imageNum];
        			if ('READ' in imageLinks) {
        				this.$('.itemDetailImages').append('<a href="' + auction.conf.urlRoot + imageLinks.READ + '?size=FULL' + '"><img src="' + auction.conf.urlRoot + imageLinks.READ + '?size=PREVIEW" /></a><p/>');
        			}
        		}
        		$('.itemDetailImages').magnificPopup({
        			delegate: 'a',
        			type: 'image',
        			mainClass: 'mfp-img-mobile',
        			gallery: {
        				enabled: true,
        				navigateByImgClick: true,
        				preload: [0,0] // Will preload 0 - before current, and 0 after the current image
        			}
        		});        		
        	}
        }

        
        return this;
    }
 
});



