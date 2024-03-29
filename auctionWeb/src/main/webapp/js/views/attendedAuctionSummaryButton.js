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
auction.views.AttendedAuctionSummaryButton = Backbone.View.extend({
    
    template: _.template(auction.utils.getTemplate(auction.conf.tpls.attendedAuctionSummaryButton)),

    events: {
        'click #attendedAuctionSummaryPush' : 'backToBidding'
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
        this.$el.html(this.template());   
        
        this.$el.show();
        
        return this;
    },
    
    backToBidding: function() {
        $(".nav-link").removeClass('active');
        $('#attendAuctions').addClass('active');
        
		auction.instances.router.navigate(
				auction.conf.hash.attendAuctions, true);


    }
       
});



