  	<div class="title"><h4><%= translate("auctionDetails") %></h4></div>
  	<table class="table table-striped table-bordered table-condensed well show-well">
       	<tbody id="auctionDetailTableBody">
       	<tr>
       		<td><%= translate("auctionId") %></td>
   			<td><%= id %></td>
       	</tr>
       	<tr>
       		<td><%= translate("auctionName") %></td>
   			<td><%= name %></td>
       	</tr>
       	<tr>
       		<td><%= translate("startDate") %></td>
   			<td><%= startDate %></td>
       	</tr>
       	<tr>
       		<td><%= translate("startTime") %></td>
   			<td><%= startTime %></td>
       	</tr>
       	<tr>
       		<td><%= translate("auctionCategory") %></td>
   			<td><%= category %></td>
       	</tr>
       	<tr>
       		<td><%= translate("auctionState") %></td>
   			<td><%= translate("auction" + state) %></td>
       	</tr>
       	</tbody>
	</table>
    