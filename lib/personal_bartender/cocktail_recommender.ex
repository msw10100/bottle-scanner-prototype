defmodule PersonalBartender.CocktailRecommender do
  @moduledoc """
  Cocktail recommendation service based on available spirits and user preferences.
  
  This module provides cocktail suggestions based on what bottles are available
  and can learn from user preferences over time.
  """
  
  @cocktail_recipes %{
    "Manhattan" => %{
      ingredients: ["whiskey", "sweet vermouth", "bitters"],
      type: "classic",
      glass: "coupe",
      description: "Classic whiskey cocktail with sweet vermouth and bitters"
    },
    "Old Fashioned" => %{
      ingredients: ["whiskey", "bitters", "sugar"],
      type: "classic", 
      glass: "rocks",
      description: "Traditional whiskey cocktail with sugar and bitters"
    },
    "Martini" => %{
      ingredients: ["gin", "dry vermouth"],
      type: "classic",
      glass: "martini",
      description: "Classic gin and dry vermouth cocktail"
    },
    "Negroni" => %{
      ingredients: ["gin", "campari", "sweet vermouth"],
      type: "classic",
      glass: "rocks", 
      description: "Italian aperitif with gin, Campari, and sweet vermouth"
    },
    "Whiskey Sour" => %{
      ingredients: ["whiskey", "lemon juice", "simple syrup"],
      type: "sour",
      glass: "coupe",
      description: "Whiskey with fresh lemon juice and simple syrup"
    },
    "Gin & Tonic" => %{
      ingredients: ["gin", "tonic water"],
      type: "highball",
      glass: "highball",
      description: "Simple gin and tonic water cocktail"
    },
    "Moscow Mule" => %{
      ingredients: ["vodka", "ginger beer", "lime juice"],
      type: "mule",
      glass: "copper mug",
      description: "Vodka with ginger beer and fresh lime"
    },
    "Daiquiri" => %{
      ingredients: ["rum", "lime juice", "simple syrup"],
      type: "sour",
      glass: "coupe", 
      description: "Classic rum cocktail with lime juice and simple syrup"
    }
  }
  
  @doc """
  Suggest cocktails based on available spirits.
  
  ## Examples
  
      iex> PersonalBartender.CocktailRecommender.suggest_cocktails(["whiskey", "sweet vermouth", "bitters"])
      {:ok, ["Manhattan", "Old Fashioned"]}
  """
  def suggest_cocktails(available_spirits) when is_list(available_spirits) do
    normalized_spirits = Enum.map(available_spirits, &normalize_spirit_name/1)
    
    matching_cocktails = 
      @cocktail_recipes
      |> Enum.filter(fn {_name, recipe} ->
        recipe_ingredients = Enum.map(recipe.ingredients, &normalize_spirit_name/1)
        has_required_spirits?(recipe_ingredients, normalized_spirits)
      end)
      |> Enum.map(fn {name, recipe} -> 
        %{
          name: name,
          ingredients: recipe.ingredients,
          type: recipe.type,
          glass: recipe.glass,
          description: recipe.description,
          match_percentage: calculate_match_percentage(recipe.ingredients, available_spirits)
        }
      end)
      |> Enum.sort_by(& &1.match_percentage, :desc)
    
    if length(matching_cocktails) > 0 do
      {:ok, matching_cocktails}
    else
      {:ok, suggest_partial_matches(normalized_spirits)}
    end
  end
  
  @doc """
  Get detailed recipe for a specific cocktail.
  """
  def get_recipe(cocktail_name) do
    case Map.get(@cocktail_recipes, cocktail_name) do
      nil -> {:error, "Recipe not found for #{cocktail_name}"}
      recipe -> {:ok, Map.put(recipe, :name, cocktail_name)}
    end
  end
  
  @doc """
  List all available cocktail recipes.
  """
  def list_all_cocktails do
    @cocktail_recipes
    |> Enum.map(fn {name, recipe} ->
      %{
        name: name,
        ingredients: recipe.ingredients,
        type: recipe.type,
        description: recipe.description
      }
    end)
    |> Enum.sort_by(& &1.name)
  end
  
  @doc """
  Recommend cocktails based on spirit type preferences.
  """
  def recommend_by_spirit_type(spirit_type, available_spirits) do
    normalized_type = normalize_spirit_name(spirit_type)
    normalized_available = Enum.map(available_spirits, &normalize_spirit_name/1)
    
    cocktails_with_spirit = 
      @cocktail_recipes
      |> Enum.filter(fn {_name, recipe} ->
        recipe_ingredients = Enum.map(recipe.ingredients, &normalize_spirit_name/1)
        normalized_type in recipe_ingredients and 
        has_required_spirits?(recipe_ingredients, normalized_available)
      end)
      |> Enum.map(fn {name, recipe} -> 
        %{
          name: name,
          ingredients: recipe.ingredients,
          description: recipe.description
        }
      end)
    
    {:ok, cocktails_with_spirit}
  end
  
  @doc """
  Interactive cocktail recommendation session.
  """
  def start_recommendation_session do
    IO.puts("🍸 Personal Bartender - Cocktail Recommendations")
    IO.puts("Tell me what spirits you have available:")
    IO.puts("(Enter spirits one by one, type 'done' when finished)")
    
    spirits = collect_spirits([])
    
    IO.puts("\n🔍 Finding cocktails you can make...")
    case suggest_cocktails(spirits) do
      {:ok, cocktails} when length(cocktails) > 0 ->
        IO.puts("\n🎯 Here's what you can make:")
        Enum.each(cocktails, fn cocktail ->
          IO.puts("• #{cocktail.name} (#{cocktail.match_percentage}% match)")
          IO.puts("  #{cocktail.description}")
          IO.puts("  Ingredients: #{Enum.join(cocktail.ingredients, ", ")}")
          IO.puts("")
        end)
        
      {:ok, []} ->
        IO.puts("\n😔 No perfect matches found with your current spirits.")
        IO.puts("Consider adding: vermouth, bitters, or mixers to unlock more cocktails!")
        
      {:error, reason} ->
        IO.puts("\n❌ Error: #{reason}")
    end
    
    spirits
  end
  
  defp collect_spirits(spirits) do
    case IO.gets("> ") |> String.trim() do
      "done" -> spirits
      "" -> collect_spirits(spirits)
      spirit -> 
        normalized = normalize_spirit_name(spirit)
        IO.puts("Added: #{normalized}")
        collect_spirits([normalized | spirits])
    end
  end
  
  defp normalize_spirit_name(spirit) do
    spirit
    |> String.downcase()
    |> String.trim()
    |> case do
      name when name in ["whiskey", "whisky", "bourbon", "rye", "scotch", "tennessee whiskey"] -> "whiskey"
      name when name in ["vodka"] -> "vodka"
      name when name in ["gin"] -> "gin"
      name when name in ["rum", "white rum", "dark rum", "spiced rum"] -> "rum"
      name when name in ["tequila", "mezcal"] -> "tequila"
      name when name in ["sweet vermouth", "red vermouth"] -> "sweet vermouth"
      name when name in ["dry vermouth", "white vermouth"] -> "dry vermouth"
      name when name in ["bitters", "angostura bitters", "orange bitters"] -> "bitters"
      name when name in ["campari"] -> "campari"
      name when name in ["cointreau", "triple sec", "orange liqueur"] -> "orange liqueur"
      name -> name
    end
  end
  
  defp has_required_spirits?(recipe_ingredients, available_spirits) do
    # Check if we have all the main spirits (exclude mixers)
    main_spirits = Enum.filter(recipe_ingredients, &is_main_spirit?/1)
    Enum.all?(main_spirits, fn ingredient -> ingredient in available_spirits end)
  end
  
  defp is_main_spirit?(ingredient) do
    ingredient in ["whiskey", "vodka", "gin", "rum", "tequila", "sweet vermouth", "dry vermouth", "campari", "bitters"]
  end
  
  defp calculate_match_percentage(recipe_ingredients, available_spirits) do
    normalized_available = Enum.map(available_spirits, &normalize_spirit_name/1)
    normalized_recipe = Enum.map(recipe_ingredients, &normalize_spirit_name/1)
    
    matching_ingredients = Enum.count(normalized_recipe, fn ingredient ->
      ingredient in normalized_available
    end)
    
    total_ingredients = length(normalized_recipe)
    
    if total_ingredients > 0 do
      round(matching_ingredients / total_ingredients * 100)
    else
      0
    end
  end
  
  defp suggest_partial_matches(available_spirits) do
    # Find cocktails where we have some ingredients
    partial_matches = 
      @cocktail_recipes
      |> Enum.map(fn {name, recipe} ->
        recipe_ingredients = Enum.map(recipe.ingredients, &normalize_spirit_name/1)
        match_percentage = calculate_match_percentage(recipe_ingredients, available_spirits)
        
        if match_percentage > 30 do
          missing_ingredients = recipe_ingredients -- available_spirits
          %{
            name: name,
            match_percentage: match_percentage,
            missing_ingredients: missing_ingredients,
            description: recipe.description
          }
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.sort_by(& &1.match_percentage, :desc)
      |> Enum.take(3)
    
    partial_matches
  end
end