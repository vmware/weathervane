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
auction.views.Navbar = Backbone.View.extend({

    /**
     * Bind the events functions to the different HTML elements
     */
    events: {
        'click #nb-icon-attendAuctions': 'attendAuctions',
        'click #nb-icon-exploreAuctions': 'exploreAuctions',
        'click #nb-icon-manageAuctions': 'manageAuctions',
        'click #nb-icon-userInfo': 'userInfo',
        'click #nb-icon-dashboard': 'dashboard',
        'click #nb-attendAuctions': 'attendAuctions',
        'click #nb-exploreAuctions': 'exploreAuctions',
        'click #nb-manageAuctions': 'manageAuctions',
        'click #nb-dashboard': 'dashboard',
        'click #nb-userInfo': 'userInfo',
        'click #nb-logout': 'logout',
    },

    /**
     * Class constructor
     * @param Object options:
     * - el: selector for the container
     * @return void
     */
    initialize: function (options) {
        'use strict';
        auction.containers.navbar = this.$el;
        this.visited = false;
    },
    
    renderLogin: function (hash) {
        'use strict';
        this.$el.html(_.template(auction.utils.getTemplate(auction.conf.tpls.navbar_login))());
        this.$el.show();
        this.visited = false;
    },

    /**
     * Renders the Nav Bar View
     * @return void
     */
     render: function (hash) {
        'use strict';
        var hashMap = {},
            i;
            
        if (!hash) {
            hash = auction.conf.hash.attendAuctions;
        }    
        if (!this.$el.html() || this.visited === false) {
        	this.visited = true;
            this.$el.html(_.template(auction.utils.getTemplate(auction.conf.tpls.navbar))(auction.session));
            $('#nb-attendAuctions').addClass('active');
            this.username = this.$('#nb-username');
        } else {
            this.username.html(auction.session.username);
        }
        
        this.$el.show();
    },

    /**
     * Logout Click Event
     * @return void
     */
    logout: function () {
        'use strict';
        auction.utils.logout();
    },
    
    attendAuctions: function(evt) {
        'use strict';
        var id = evt.target.id;
        
        $(".nav-link").removeClass('active');
        $('#nb-attendAuctions').addClass('active');
        
		auction.instances.router.navigate(
				auction.conf.hash.attendAuctions, true);
    },

    exploreAuctions: function(evt) {
        'use strict';
        var id = evt.target.id;
        
        $(".nav-link").removeClass('active');
        $('#nb-exploreAuctions').addClass('active');
        
		auction.instances.router.navigate(
				auction.conf.hash.exploreAuctions, true);
    },

    manageAuctions: function(evt) {
        'use strict';
        var id = evt.target.id;
        
        $(".nav-link").removeClass('active');
        $('#nb-manageAuctions').addClass('active');
        
		auction.instances.router.navigate(
				auction.conf.hash.manageAuctions, true);
    },

    dashboard: function(evt) {
        'use strict';
        var id = evt.target.id;
        
        $(".nav-link").removeClass('active');
        $('#nb-dashboard').addClass('active');
        
		auction.instances.router.navigate(
				auction.conf.hash.dashboard, true);
    },

    userInfo: function(evt) {
        'use strict';
        var id = evt.target.id;
        
        $(".nav-link").removeClass('active');
        $('#nb-userInfo').addClass('active');
        
		auction.instances.router.navigate(
				auction.conf.hash.userInfo, true);
    }
});
