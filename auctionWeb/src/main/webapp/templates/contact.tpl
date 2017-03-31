<div class="row clearfix">
    <div class="col-lg-9 columns">
        <form class="form-horizontal">
            <fieldset>
                <h3><%= translate("contactUs") %></h3>
                <div id="contact-error" class="hide col-lg-8 alert alert-block alert-error fade in">
                    <a data-dismiss="alert" class="close">x</a>
                    <h4 class="alert-heading"><%= translate("ohSnap") %></h4>
                    <p></p>
                </div>
				<div class="row col-lg-4">
                	<div class="control-group">
	                    <label for="name-input" class="control-label"><%= translate("name") %></h3>:</label>
	                    <div class="controls">
	                        <input type="text" value="" id="name-input" class="col-lg-4 focused" maxlength="100">
	                    </div>
	                </div>
	                <div class="control-group">
	                    <label class="control-label"><%= translate("email") %></h3>:</label>
	                    <div class="controls">
	                        <input type="text" value="" id="email-input" class="col-lg-4 focused" maxlength="100">
	                    </div>
	                </div>
	                <div class="control-group">
	                    <label class="control-label"><%= translate("phone") %>:</label>
	                    <div class="controls">
	                        <input type="text" value="" id="phone-input" class="col-lg-4 focused" maxlength="100">
	                    </div>
	                </div>
	                <div class="control-group">
	                    <label class="control-label"><%= translate("message") %>:</label>
	                    <div class="controls">
	                        <textarea rows="3" id="message-input" class="col-lg-4"></textarea>
	                    </div>
	                </div>
	                <div class="form-actions">
	                    <button id="sendBtn" class="btn green-btn"><%= translate("send") %></button>
	                </div>
				</div>
            </fieldset>
        </form>
    </div>
    <div class="col-lg-2 sidebar">
        <h3><%= translate('nearestLocation') %></h3>
        <p><%= location %></p>
    </div>
    <% if (!auction.utils.loggedIn()) { %>
     <div class="col-lg-2 columns sidebar">
        <h3><%= translate("nanoTraderLogin") %></h3>
        <p><%= translate("alreadyRegistered") %></p>
        <p><a id="showLoginBtn"><%= translate("goToLoginPage") %></a></p>
    </div>
    <% } %>
</div>
