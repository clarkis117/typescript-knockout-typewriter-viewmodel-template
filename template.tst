

${
	using System.Reflection;
	using System.Text;

	public static string TypeScriptNameSpace {get; set; } = "SmarterPlanetSecWeb";
	public static string ModelNameSpace {get;} = "SmarterPlanetSecBackend.Models";

	Template(Settings settings)
	{
		settings.IncludeCurrentProject()
		.IncludeReferencedProjects();
	}

	//gets KO Type, trims square brackets off if array
	string KnockoutType(Property p) {
		if (p.Type.IsEnumerable) {
			return p.Type.Name.TrimEnd('[',']');
		}

		return p.Type;
	}

	string PropertyFilter(Property property) {
		var type = KnockoutType(property);

		var parent = property.Parent as Typewriter.CodeModel.Class; 

		bool IsGraph = IsGraphObj(parent);

		if(IsGraph)
		{
			if(property.Type.FullName.StartsWith(ModelNameSpace))
			{
				//return $"public {property.Name} = new {property.Type}(null)";
				return $"public {property.Name}:{property.Type} = new {property.Type}(null);";
			}
		}

		if(property.Attributes.Any(x => x.Name == "JsonIgnore"))
		{
			return null;
		}
		else if (IsEnumerableViewModel(property))
		{
			return $"public {property.Name} = ko.observableArray<Knockout{type}>([]);";
		} 
		else if (property.Type.IsEnumerable)
		{
			return $"public {property.Name} = ko.observableArray<{type}>([]);";
		}

		return $"public {property.Name} = ko.observable<{type}>();";
	}

	bool IsEnumerableViewModel(Property p) {
		string type = KnockoutType(p);

		return p.Type.IsEnumerable && type.EndsWith("ViewModel");
	}

   string ClassDoesItExtend(Class c)
   {
		if(c.BaseClass == null)
		{
			return c.Name;
		}
		else
		{
			return $"{c.Name} extends {c.BaseClass.Name}";
		}
   }

   string SuperDoesItExtend(Class c)
   {
		if(c.BaseClass == null)
		{
			return null;
		}
		else
		{
			return "super(model);";
		}
   }

   string InterfaceDoesItExtend(Class c)
   {
		if(c.BaseClass == null)
		{
			return $"I{c.Name}";
		}
		else
		{
			return $"I{c.Name} extends I{c.BaseClass.Name}";
		}
   }

   string InterfaceTypeFilter(Property p)
   {
		if(p.Attributes.Any(x => x.Name == "JsonIgnore"))
		{
			return null;

		}
		else if(p.Type.FullName.Contains(ModelNameSpace))
		{
			return $"{p.Name}:I{p.Type};";
		}
		else
		{
			return $"{p.Name}:{p.Type};";
		}
   }

   string MapDefaultValueFilter(Property p)
   {
		var parent = p.Parent as Typewriter.CodeModel.Class;

		bool IsGraph = IsGraphObj(parent);
		//todo test with new object and just the declaration 
		if(IsGraph)
		{
			if(p.Type.FullName.StartsWith(ModelNameSpace))
			{
				//return $"public {property.Name} = new {property.Type}(null);";
				return $"this.{p.Name}.map(null);";
			}
		}

		if(p.Attributes.Any(x => x.Name == "JsonIgnore")) //if ignored value
		{
			return null;

		}
		else if(p.Type.ToString() == "boolean")
		{
			return $"this.{p.Name}(false);";
		}
		else if(p.Type.ToString() == "number")
		{
			return $"this.{p.Name}(0);";
		}
		else if(p.Type.ToString() == "string")
		{
			//var a = @"""";
			return $"this.{p.Name}({@""""""});";
		}
		else if(p.Type.IsEnumerable)
		{
			//if it is an enumerable type
			return $"this.{p.Name}({"[]"});";
		}
		else if(p.Type.FullName.StartsWith(ModelNameSpace))
		{
			//if it is a complex type from our data model
			return $"this.{p.Name}(new {p.Type}(null));";
		}
		else
		{
			return null;
		}
   }

   //todo test with new object and just the declaration
   bool IsGraphObj(Class obj)
   {
		if(obj != null && obj.Attributes.Any(x => x.FullName.Contains("GraphObject")))
		{
			return true;
		}

		return false;
   }

   string MapPorpertyFilter(Property p)
   {
		var parent = p.Parent as Typewriter.CodeModel.Class; 

		bool IsGraph = IsGraphObj(parent);
 
		if(IsGraph)
		{
			if(p.Type.FullName.StartsWith(ModelNameSpace))
			{
				//return $"public {property.Name} = new {property.Type}(null);";
				//return $"this.{p.Name} = new {p.Type}(model.{p.Name});";
				return $"this.{p.Name}.map(model.{p.Name});";
			}
		}


		if(p.Attributes.Any(x => x.Name == "JsonIgnore")) //if ignored value
		{
			return null;
		}
		else if(IsEnumerableViewModel(p))
		{
			return $"this.{p.Name}(model.{p.Name}.map(this.map{p.Name}));";
		}
		else if(p.Type.FullName.Contains(ModelNameSpace) && !p.Type.IsEnumerable)
		{
			return $"this.{p.Name}(new {p.Type}(model.{p.Name}));";
		}
		else if(p.Type.FullName.Contains(ModelNameSpace) && p.Type.IsEnumerable)
		{
			var covariantclasses = CovariantCollectionReader(p);

			if(covariantclasses != null) //if covariant
			{
				var sb = new StringBuilder();
				
				var tabs = "					";

				sb.AppendLine($"this.{p.Name}([]);");

				sb.AppendLine($"model.{p.Name}.forEach((item) => " );
				sb.AppendLine(tabs+"{");

				foreach(var item in covariantclasses)
				{
					sb.AppendLine(tabs+$"if(item.$type == {item}.Type)");

					sb.AppendLine(tabs+"{");

					sb.AppendLine(tabs+$"var {item.ToLower()} = new {item}(item as I{item});"); //new item as

					sb.AppendLine(tabs+$"this.{p.Name}.push({item.ToLower()});");
					
					sb.AppendLine(tabs+"}");
				}


				sb.AppendLine(tabs+"});");

				return sb.ToString();
			}
			else //if not covariant
			{
				var sb = new StringBuilder();
				
				var tabs = "					";

				sb.AppendLine($"this.{p.Name}([]);");

				sb.AppendLine($"model.{p.Name}.forEach((item) => " );
				sb.AppendLine(tabs+"{");

				var item = p.Type.TypeArguments.Single().ToString();

					//sb.AppendLine(tabs+$"if(item.$type == {item}.Type)");

					//sb.AppendLine(tabs+"{");

					sb.AppendLine(tabs+$"var {item.ToLower()} = new {item}(item as I{item});"); //new item as

					sb.AppendLine(tabs+$"this.{p.Name}.push({item.ToLower()});");
					
					//sb.AppendLine(tabs+"}");

					sb.AppendLine(tabs+"});");

				return sb.ToString();
				//return  $"{p.Type} this.{p.Name}(new Array{p.Type.TypeParameters}(model.{p.Name}));";
			}
		}
		else
		{
			return $"this.{p.Name}(model.{p.Name});";
		}
   }

   IList<string> CovariantCollectionReader(Property p)
   {
		if(p.Attributes.Any(x => x.FullName.Contains("CovariantCollection")))
		{
			var attval = p.Attributes.Single(x => x.FullName.Contains("CovariantCollection")).Value;

			var classes = attval.Replace("typeof(", "").Replace(")","").Split(',');

			var cleanedclasses = new List<string>();

			foreach(var item in classes)
			{
					cleanedclasses.Add(item.Split('.').Last());
			}

			return cleanedclasses;
		}
		else
		{
			return null;
		}
   }
}


/// <reference path="./typings/knockout/knockout.d.ts" />
namespace SmarterPlanetSecWeb {

	$Classes(SmarterPlanetSecBackend.Models.Content*)[
	/**
	 * Interface for: $FullName
	 */
	export interface $InterfaceDoesItExtend {
		$Properties[
		$InterfaceTypeFilter]
		$type:string;
	}

	/**
	 * Knockout base view model for $FullName
	 */
	export class $ClassDoesItExtend {
		
		$Properties[
		$PropertyFilter]

		public $shortType:string = "$Name";

		public static ShortType:string = "$Name";

		public $type:string = "$FullName";

		public static Type:string = "$FullName";

		constructor(model: I$Name) {
			$SuperDoesItExtend

			this.map(model);
		}

		/**
		 * Map $Name model to Knockout view model
		 */
		public map = (model: I$Name): void => {
			if(model != null)
			{
				$Properties[
				 $MapPorpertyFilter
				 ]
			}
			else //if null
			{
				$Properties[
				 $MapDefaultValueFilter
				 ]
			}
		}

		$Properties(x => IsEnumerableViewModel(x))[
		/**
		 * Map $KnockoutType equivalent Knockout view model. Override to customize.
		 */
		public map$Name(model: $KnockoutType) {
			return new Knockout$KnockoutType(model);
		}]

		/**
		 * Returns a plain JSON object with current model properties
		 */
	}]
}

