package react;
import react.ReactComponent;
import react.ReactMacro.jsx;
import react.LoginBox.LoginBoxProps;

typedef RegisterBoxState = {firstName:String,lastName:String,email:String,password:String,error:String};

/**
 * ...
 * @author fbarbut
 */
class RegisterBox extends react.ReactComponentOfPropsAndState<LoginBoxProps,RegisterBoxState>
{

	public function new(props:LoginBoxProps) 
	{
		if (props.redirectUrl == null) props.redirectUrl = "/";	
		super(props);		
		this.state = {firstName:"",lastName:"",email:"",password:"",error:null};
	}
	
	
	override public function render(){
		
		return jsx('
			<div>
				<$Error error="${state.error}" />
				<form action="" method="post" className="form-horizontal">
					<div className="form-group">
						<label htmlFor="firstName" className="col-sm-4 control-label">Nom : </label>
						<div className="col-sm-8">
							<input id="firstName" type="text" name="firstName" value="${state.firstName}" className="form-control" onChange={onChange}/>					
						</div>					
					</div>
					<div className="form-group">
						<label htmlFor="lastName" className="col-sm-4 control-label">Prénom : </label>
						<div className="col-sm-8">
							<input id="lastName" type="text" name="lastName" value="${state.lastName}" className="form-control" onChange={onChange}/>					
						</div>					
					</div>
					<div className="form-group">
						<label htmlFor="email" className="col-sm-4 control-label">Email : </label>
						<div className="col-sm-8">
							<input id="email"  type="text" className="form-control" name="email" value="${state.email}" onChange={onChange} />			
						</div>
					</div>
					<div className="form-group">
						<label htmlFor="password" className="col-sm-4 control-label">Mot de passe : </label>
						<div className="col-sm-8">
							<input id="password" type="password" name="password" value="${state.password}" className="form-control" onChange={onChange}/>					
						</div>					
					</div>
					<p className="text-center">
						<a onClick={submit} className="btn btn-primary btn-lg" ><span className="glyphicon glyphicon-chevron-right"></span> Inscription</a>
					</p>
				</form>
				<hr/>
				<p className="text-center">
					<b>Déjà inscrit ? </b>
					<a onClick={loginBox} className="btn btn-default"><span className="glyphicon glyphicon-user"></span> Connectez-vous ici</a>
				</p>
			</div>
			
		');
	}
	
	/**
	 * @doc https://facebook.github.io/react/docs/forms.html
	 */
	function onChange(e:js.html.Event){
		e.preventDefault();
		
		var name :String = untyped e.target.name;
		var value :String = untyped e.target.value;
		trace('$name : $value');
		Reflect.setField(state, name, value);
		this.setState(this.state);
	}
	
	/**
	 * displays a login box
	 */
	public function loginBox(){
		
		var body = js.Browser.document.querySelector('#myModal .modal-body');
		ReactDOM.unmountComponentAtNode( body );
	
		js.Browser.document.querySelector("#myModal .modal-title").innerHTML = "Connexion";
		ReactDOM.render(jsx('<$LoginBox redirectUrl="${props.redirectUrl}" />'),  body );
	}

	
	public function submit(e:js.html.Event ){
		
		if (state.email == ""){
			setError("Veuillez saisir votre email");
			return;
		}
		
		if (state.password == ""){
			setError("Veuillez saisir un mot de passe");
			return;
		}
		if (state.firstName == ""){
			setError("Veuillez saisir votre prénom");
			return;
		}
		if (state.lastName == ""){
			setError("Veuillez saisir votre nom de famille");
			return;
		}
		
		//lock button
		var el : js.html.Element = cast e.target;
		el.classList.add("disabled");
		
		var req = new haxe.Http("/api/user/register");
		req.addParameter("firstName", state.firstName);
		req.addParameter("lastName", state.lastName);
		req.addParameter("email", state.email);
		req.addParameter("password", state.password);
		req.addParameter("redirecturl", props.redirectUrl);
		
		req.onData = function(d){
			
			el.classList.remove("disabled");
			
			var d = haxe.Json.parse(d);
			if (Reflect.hasField(d, "error"))	setError(d.error.message);
			if (Reflect.hasField(d, "success")) js.Browser.window.location.href = props.redirectUrl;
		}
		
		req.request(true);
	}
	
	function setError(err:String){
		this.setState(cast {error:err});
	}
	
}