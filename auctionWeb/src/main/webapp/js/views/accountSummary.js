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
 * View Class for the Account Summary
 */
auction.views.AccountSummary = Backbone.View.extend({
    
	/**
     * Class constructor
     * @param Object options:
     * - model: auction.models.AccountSummary instance
     * @return void
     */
    initialize : function (options) {
		'use strict';
        auction.containers.accountSummary = this.$el;
    },

    /**
     * Renders the Account Summary View
     * @param Object account: Instance of auction.models.account
     * @param Object portfolioSummary: Instance of auction.models.PortfolioSummary
     * @return void
     */
     render : function (account, portfolioSummary) {
		'use strict';		
		var data = _.extend(portfolioSummary.toJSON(), account.toJSON());
        this.$el.html(_.template(auction.utils.getTemplate(auction.conf.tpls.accountSummary))(data));
        this.$el.show();
    }
});