<h5>Current Bid</h5>
<table class="table">
    <tbody>
       	<tr class=<%= "nextBidRow" + divId %>>
       		<td><%= translate("bidAmount") %></td>
   			<td><%= auction.utils.printCurrency(amount) %></td>
       	</tr>
       	<tr class=<%= "nextBidRow" + divId %>>
       		<td><%= translate("bidState") %></td>
   			<td><%= translate("bid" + biddingMessage) %></td>
       	</tr>
       	<tr/>
	</tbody>
 </table>
	