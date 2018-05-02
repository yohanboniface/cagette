package service;
import Common;

/**
 * Distribution Service
 * @author web-wizard
 */
class DistributionService
{
	
	var distribution : db.Distribution;

	public function new(d:db.Distribution) 
	{
		this.distribution = d;
		
	}
	
	/**
	 * checks if dates are correct and if that there is no other distribution in the same time range
	 *  and for the same contract and place
	 * @param d
	 */
	public static function checkDistrib(d:db.Distribution) {
		
		var t = sugoi.i18n.Locale.texts;
		var view = App.current.view;
		var c = d.contract;

		var distribs1;
		var distribs2;	
		var distribs3;	
		//We are checking that there is no existing distribution with an overlapping time frame for the same place and contract
		if (d.id == null) { //We need to check there the id as $id != null doesn't work in the manager.search
			//Looking for existing distributions with a time range overlapping the start of the about to be created distribution
			distribs1 = db.Distribution.manager.search($contract == c && $place == d.place && $date <= d.date && $end >= d.date, false);
			//Looking for existing distributions with a time range overlapping the end of the about to be created distribution
			distribs2 = db.Distribution.manager.search($contract == c && $place == d.place && $date <= d.end && $end >= d.end, false);	
			//Looking for existing distributions with a time range included in the time range of the about to be created distribution		
			distribs3 = db.Distribution.manager.search($contract == c && $place == d.place && $date >= d.date && $end <= d.end, false);	
		}
		else {
			//Looking for existing distributions with a time range overlapping the start of the about to be created distribution
			distribs1 = db.Distribution.manager.search($contract == c && $place == d.place && $date <= d.date && $end >= d.date && $id != d.id, false);
			//Looking for existing distributions with a time range overlapping the end of the about to be created distribution
			distribs2 = db.Distribution.manager.search($contract == c && $place == d.place && $date <= d.end && $end >= d.end && $id != d.id, false);	
			//Looking for existing distributions with a time range included in the time range of the about to be created distribution		
			distribs3 = db.Distribution.manager.search($contract == c && $place == d.place && $date >= d.date && $end <= d.end && $id != d.id, false);	
		}
			
		if (distribs1.length != 0 || distribs2.length != 0 || distribs3.length != 0) {
			throw t._("There is already a distribution at this place overlapping with the time range you've selected.");
		}
 
		if (d.date.getTime() > c.endDate.getTime()) throw t._("The date of the delivery must be prior to the end of the contract (::contractEndDate::)", {contractEndDate:view.hDate(c.endDate)});
		if (d.date.getTime() < c.startDate.getTime()) throw t._("The date of the delivery must be after the begining of the contract (::contractBeginDate::)", {contractBeginDate:view.hDate(c.startDate)});
		
		if (c.type == db.Contract.TYPE_VARORDER ) {
			if (d.date.getTime() < d.orderEndDate.getTime() ) throw t._("The distribution start date must be set after the orders end date.");
			if (d.orderStartDate.getTime() > d.orderEndDate.getTime() ) throw t._("The orders end date must be set after the orders start date !");
		}

	}

	/**
	* Creates a new distribution and prevents distribution overlapping and other checks
	*  @param contract
	*  @param text
	*  @param date
	*  @param end
	*  @param placeId
	*  @param distributor1Id
	*  @param distributor2Id
	*  @param distributor3Id
	*  @param distributor4Id
	*  @param orderStartDate
	*  @param orderEndDate
	*/
	 public static function create(contract:db.Contract,text:String,date:Date,end:Date,placeId:Int,
	 	distributor1Id:Int,distributor2Id:Int,distributor3Id:Int,distributor4Id:Int,
		orderStartDate:Date,orderEndDate:Date):db.Distribution {
		
		var d = new db.Distribution();
		d.contract = contract;
		d.text = text;
		d.date = date;
		d.place = db.Place.manager.get(placeId);
		d.distributor1 = db.User.manager.get(distributor1Id);
		d.distributor2 = db.User.manager.get(distributor2Id);
		d.distributor3 = db.User.manager.get(distributor3Id);
		d.distributor4 = db.User.manager.get(distributor4Id);
		if(contract.type==db.Contract.TYPE_VARORDER){
			d.orderStartDate = orderStartDate;
			d.orderEndDate = orderEndDate;
		}
					
		if (end == null) {
			d.end = DateTools.delta(d.date, 1000.0 * 60 * 60);
		}
		else {
			d.end = new Date(d.date.getFullYear(), d.date.getMonth(), d.date.getDate(), end.getHours(), end.getMinutes(), 0);
		} 
		
		DistributionService.checkDistrib(d);
		
		var e :Event = NewDistrib(d);
		App.current.event(e);
		
		if (d.date == null){
			return null;
		} 
		else {
			d.insert();
			return d;
		}
	}

	/**
	* Modifies an existing distribution and prevents distribution overlapping and other checks
	*  @param d
	*  @param text
	*  @param date
	*  @param end
	*  @param placeId
	*  @param distributor1Id
	*  @param distributor2Id
	*  @param distributor3Id
	*  @param distributor4Id
	*  @param orderStartDate
	*  @param orderEndDate
	*/
	 public static function edit(d:db.Distribution,text:String,date:Date,end:Date,placeId:Int,
	 	distributor1Id:Int,distributor2Id:Int,distributor3Id:Int,distributor4Id:Int,
		orderStartDate:Date,orderEndDate:Date):db.Distribution {

		//We prevent others from modifying it
		d.lock();

		d.text = text;
		d.date = date;
		d.place = db.Place.manager.get(placeId);
		d.distributor1 = db.User.manager.get(distributor1Id);
		d.distributor2 = db.User.manager.get(distributor2Id);
		d.distributor3 = db.User.manager.get(distributor3Id);
		d.distributor4 = db.User.manager.get(distributor4Id);
		if(d.contract.type==db.Contract.TYPE_VARORDER){
			d.orderStartDate = orderStartDate;
			d.orderEndDate = orderEndDate;
		}
					
		if (end == null) {
			d.end = DateTools.delta(d.date, 1000.0 * 60 * 60);
		}
		else {
			d.end = new Date(d.date.getFullYear(), d.date.getMonth(), d.date.getDate(), end.getHours(), end.getMinutes(), 0);
		} 
		
		DistributionService.checkDistrib(d);

		App.current.event(EditDistrib(d));
		
		if (d.date == null){
			return null;
		} 
		else {
			d.update();
			return d;
		}
	}
}