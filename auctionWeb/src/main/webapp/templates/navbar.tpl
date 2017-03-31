<div class="container">
	<div class="navbar-header">
		<button class="navbar-toggle" data-target=".nav-ex1-collapse"
			data-toggle="collapse" type="button">
			<span class="icon-bar"></span> <span class="icon-bar"></span> <span
				class="icon-bar"></span>
		</button>
		<a class="navbar-brand" id="nb-brand"><%= translate("auction")
			%></a>
	</div>
	<div class="navbar-collapse collapse">
		<ul class="nav navbar-nav">
			<li id ="nb-attendAuctions"
				class="nav-link">
			<a><span id="nb-icon-attendAuctions"
				class="glyphicon glyphicon-hand-up"></span><%=
				translate("attendAuctions") %></a>
			</li>
			<li id ="nb-exploreAuctions"
				class="nav-link">
			<a><span id="nb-icon-exploreAuctions"
				class="glyphicon glyphicon-eye-open"></span><%=
				translate("exploreAuctions") %></a>
			</li>
			<li id="nb-manageAuctions" class="nav-link"><a><span
					id="nb-icon-manageAuctions" class="glyphicon glyphicon-usd"></span><%=
					translate("manageAuctions") %></a></li>
			<li id="nb-dashboard" class="nav-link"><a><span
					id="nb-icon-dashboard" class="glyphicon glyphicon-dashboard"></span><%=
					translate("dashboard") %></a></li>
		</ul>
		<ul class="nav navbar-nav pull-right">
			<li id="nb-userInfo" class="nav-link"><a><span
					id="nb-icon-userInfo" class="glyphicon glyphicon-user"></span><span
					id="nb-username"><%= username %></span></a></li>
			<li><a id="nb-logout"><%= translate("logout") %></a></li>
		</ul>
	</div>
</div>
