# Personal Bartender 🍸

An AI-powered bottle recognition and cocktail recommendation system built with the Chorus framework. Test LLM vision capabilities for identifying liquor bottles and get personalized cocktail suggestions.

## Features

- **🔍 Bottle Recognition**: Identify liquor bottles from photos using LLM vision
- **🧠 Learning Agent**: Chorus agent that improves accuracy from user corrections  
- **🍹 Cocktail Recommendations**: Get cocktail suggestions based on your bottle collection
- **📸 Multiple Input Methods**: Local files, URLs, or interactive scanning sessions
- **📊 Progress Tracking**: Monitor agent learning and recognition statistics

## Quick Start

### 1. Set Up API Keys

```bash
# For OpenAI GPT-4 Vision (recommended)
export OPENAI_API_KEY="your-openai-api-key"

# Or for Google Gemini Vision
export GOOGLE_API_KEY="your-gemini-api-key"
export VISION_PROVIDER="gemini"

# For testing without API calls
export VISION_PROVIDER="test"
```

### 2. Install Dependencies

```bash
cd chorus-examples/personal_bartender
mix deps.get
```

### 3. Start the Application

```bash
iex -S mix
```

## Usage Examples

### Basic Bottle Recognition

```elixir
# Test with a URL
PersonalBartender.scan_bottle("https://example.com/bottle.jpg")

# Start the learning agent and scan local files
PersonalBartender.start_agent()
PersonalBartender.scan_with_agent("bottle.jpg")  # place in priv/data/images/

# Get cocktail recommendations
PersonalBartender.recommend_cocktails(["whiskey", "sweet vermouth", "bitters"])
```

### Interactive Sessions

```elixir
# Interactive scanning session
PersonalBartender.start_scanning_session()

# Interactive cocktail recommendations  
PersonalBartender.start_cocktail_session()

# List available test images
PersonalBartender.list_available_images()

# Quick test with a local image
PersonalBartender.quick_test("my_bottle.jpg")
```

### Agent Learning Features

```elixir
# Correct a misidentification to help the agent learn
original = %{brand: "Unknown", type: "Whiskey", confidence: 0.3}
correction = %{brand: "Maker's Mark", type: "Bourbon Whiskey", notes: "Red wax seal"}
PersonalBartender.correct_identification(original, correction)

# Get agent statistics and learning progress
PersonalBartender.get_agent_stats()

# Search the agent's accumulated knowledge
PersonalBartender.search_bottle_knowledge("bourbon")
```

### Multi-Provider Comparison

```elixir
# Compare results from multiple LLM providers for the same image
PersonalBartender.compare_providers("my_bottle.jpg")

# Returns detailed comparison including:
# - Recognition results from each provider (OpenAI, Claude, Gemini)
# - Response times and estimated costs
# - Agreement analysis between providers
# - Recommendation for best provider based on accuracy, speed, and cost
```

## Testing Local Images

1. Drop bottle images into `priv/data/images/`
2. Run `PersonalBartender.list_available_images()` to see available files
3. Test with `PersonalBartender.quick_test("filename.jpg")`

## Vision Provider Options

### OpenAI GPT-4 Vision (Default)
- **Pros**: Most accurate, best text reading
- **Cons**: Most expensive (~$0.01-0.03 per image)
- **Setup**: Set `OPENAI_API_KEY`

### Google Gemini Vision  
- **Pros**: Good accuracy, better pricing
- **Cons**: Requires image download/base64 conversion
- **Setup**: Set `GOOGLE_API_KEY` and `VISION_PROVIDER="gemini"`

### Claude 3.5 Sonnet Vision
- **Pros**: Excellent reasoning, detailed analysis
- **Cons**: Moderate cost, requires image download
- **Setup**: Set `ANTHROPIC_API_KEY` and `VISION_PROVIDER="claude"`

### Test Mode
- **Pros**: No API calls, instant responses
- **Cons**: Returns mock data
- **Setup**: Set `VISION_PROVIDER="test"`

### Multi-Provider Mode
- **Pros**: Compare all providers simultaneously, find best option
- **Cons**: Higher cost (uses all available APIs)
- **Setup**: Use `PersonalBartender.compare_providers/1` function

## Architecture

### Core Components

- **`PersonalBartender`**: Main API module with convenient functions
- **`PersonalBartender.BottleScannerAgent`**: Chorus agent with learning capabilities
- **`PersonalBartender.VisionAPI`**: Multi-provider vision API interface
- **`PersonalBartender.BottleScanner`**: Direct vision processing (no learning)
- **`PersonalBartender.CocktailRecommender`**: Cocktail suggestion engine

### Chorus Agent Features

The bottle scanner agent uses Chorus's semantic memory to:
- Remember bottle identifications and user corrections
- Learn from misidentifications to improve accuracy
- Build knowledge about bottle characteristics over time
- Provide context-aware recommendations

## Example Workflow

1. **Start the agent**: `PersonalBartender.start_agent()`
2. **Scan bottles**: `PersonalBartender.scan_with_agent("bottle1.jpg")`
3. **Correct mistakes**: Help the agent learn from any errors
4. **Build collection**: Scan more bottles to build your inventory
5. **Get recommendations**: `PersonalBartender.recommend_cocktails(your_spirits)`
6. **Track progress**: Monitor learning with `PersonalBartender.get_agent_stats()`

## Recognition Accuracy Tips

- **Good lighting**: Ensure labels are clearly visible
- **Clear labels**: Face labels toward camera when possible
- **Multiple angles**: Try different angles if recognition fails
- **Provide corrections**: Help the agent learn from mistakes
- **Common brands**: Start with well-known brands for best results

## Supported Bottle Types

The system can identify:
- **Whiskey**: Bourbon, rye, scotch, Irish, Tennessee whiskey
- **Vodka**: Premium and standard brands
- **Gin**: London dry, contemporary styles
- **Rum**: White, dark, spiced varieties
- **Tequila**: Blanco, reposado, añejo
- **Liqueurs**: Campari, vermouth, triple sec, etc.

## Cocktail Database

Includes classic cocktails:
- Manhattan, Old Fashioned, Martini, Negroni
- Whiskey Sour, Daiquiri, Moscow Mule
- Gin & Tonic, and more

## Development

### Running Tests

```bash
# Test bottle recognition accuracy
PersonalBartender.BottleScanner.run_recognition_tests()

# Test cocktail recommendations
PersonalBartender.CocktailRecommender.list_all_cocktails()
```

### Adding New Features

- Extend `PersonalBartender.BottleScannerAgent` for new recognition capabilities
- Add cocktail recipes in `PersonalBartender.CocktailRecommender`
- Implement new vision providers in `PersonalBartender.VisionAPI`

## Next Steps

This proof-of-concept demonstrates:
✅ LLM vision can identify bottles with good accuracy  
✅ Chorus agents can learn and improve over time  
✅ Multi-provider vision API abstraction works  
✅ Local file and URL processing both work  

For production development:
- Implement persistent storage (PostgreSQL + pgvector)
- Add user authentication and collections
- Build web interface with Phoenix LiveView
- Implement subscription billing
- Add mobile-responsive photo capture
- Create social features for sharing collections

---

**🧪 Ready to test bottle recognition? Drop some bottle images in `priv/data/images/` and run `PersonalBartender.quick_test("filename.jpg")`!**