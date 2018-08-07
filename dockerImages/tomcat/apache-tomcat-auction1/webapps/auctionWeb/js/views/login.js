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
 * View Class for the Login
 */
auction.views.Login = Backbone.View.extend({

    /**
     * Bind the events functions to the different HTML elements
     */
    events: {
        'click #loginBtn' : 'login',
        'click #showRegistrationBtn' : 'registration'
    },

    /**
     * Class constructor
     * @param Object options
     * @return void
     */
    initialize: function (options) {
        'use strict';
        auction.containers.login = this.$el;
    },

    /**
     * Renders the Login View
     * @param mixed errorKey: Name of an error key from auction.strings to be displayed. It can be null (no error show on render)
     * @return void
     */
     render: function (errorKey) {
        'use strict';
        var loginError;
        if (!this.$el.html()) {
            this.$el.html(_.template( auction.utils.getTemplate(auction.conf.tpls.login) )());
            if (errorKey) {
                loginError = this.$('#login-error');
                loginError.find('p').html(translate(errorKey));
                loginError.show();
            }
        }
        this.$el.show();
    },

    /**
     * Registration event
     * @return void
     */
    registration: function () {
        'use strict';
        window.location = auction.conf.hash.registration;
    },

    /**
     * Login event
     * @return void
     */
    login: function (event) {
        'use strict';
        event.preventDefault();
        // Cache the login and password controls for performance
        var loginControl = this.$('#login-control'),
            passwordControl = this.$('#password-control'),
            loginError = this.$('#login-error'),
            username = this.$('#username-input').val(),
            password = this.$('#password-input').val(),
            view = this;
        auction.utils.login (username, password, {
            success : function (jqXHR, textStatus) {
                //Clear the credentials from the inputs
                view.$('#username-input').val('');
                view.$('#password-input').val('');

                //Clear any previous error
                loginError.hide();
                loginControl.removeClass('error');
                passwordControl.removeClass('error');

                //Show the loading page, hide the login page and render the dashboard
                auction.instances.router.navigate(auction.conf.hash.attendAuctions, true);
            },
            error : function (jqXHR, textStatus, errorThrown) {
                loginError.show();
                switch (jqXHR.status) {
                    case 401:
                        loginControl.addClass('error');
                        passwordControl.addClass('error');
                        loginError.find('p').html(translate('invalidUser'));
                        break;
                    default:
                        break;
                }
            }
        });
    }
});
