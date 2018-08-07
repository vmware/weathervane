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
auction.views.PostBid = Backbone.View.extend({
    
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.bidForm)),

    initialize : function(options) {
    	this.divId = options.divId;
        this.model.on('change:id', this.render, this);
    },
    
    events: {
    	'click .postBidSubmit' : 'postBid'
    },
    
    /**
     * Renders the next bid View
     * @author Harold Rosenberg (hrosenbe@vmware.com)
     * @return void
     */
    render: function() {
        'use strict';
   
        this.$el.empty();
                        
        var tmplAttributes = this.model.clone();
        tmplAttributes['divId'] = this.divId;
        this.$el.html(this.template(tmplAttributes.attributes));   
        
        this.$el.show();
		
        return this;
    },
    
    afterBid: function() {
    	
    	this.render();
    	var auctionId = this.model.get("auctionId");
    	var itemId = this.model.get("itemId");
        auction.instances.postBidModels[this.divId].clear({silent: true});
        auction.instances.postBidModels[this.divId].set({"auctionId": auctionId, "itemId": itemId, "message": "BIDNOW"});

    },
    
    postBid: function(event) {
    	event.preventDefault();
    	
    	this.model.unset("id", {silent: true});
    	this.model.set({'amount': $('#bidForm' + this.divId + ' .postBidValue').val(), 'userId': auction.session.userid}, {silent: true});
    	this.model.save();		    	
    }
});



