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
auction.views.Footer = Backbone.View.extend({
    
    /**
     * Bind the events functions to the different HTML elements
     */
    events : {
    },
    
    /**
     * Class constructor
     * @author Carlos Soto <carlos.soto>
     * @param Object options: options for the view
     * @return void
     */
    initialize : function (options) {
        'use strict';
        auction.containers.footer = this.$el;
    },

    /**
     * Renders the Footer View
     * @author Winston Koh
     * @return void
     */
    render: function() {
        'use strict';
        var footer = _.template(auction.utils.getTemplate(auction.conf.tpls.footer))();
        this.$el.html(footer);
    },

    /**
     * Contact link click event
     * @return void
     */
    contact: function () {
        'use strict';
        window.location = auction.conf.hash.contact;
    },

    /**
     * Help link click event
     * @return void
     */
    help: function () {
        'use strict';
        window.location = auction.conf.hash.help;
    }
});
