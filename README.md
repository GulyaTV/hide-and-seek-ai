# Hide and Seek with AI 🤖🙈

**Inspired by OpenAI's Hide and Seek Experiment**

A Godot 4.6 implementation of reinforcement learning agents playing hide and seek, featuring emergent behaviors and self-improving AI strategies.

## 🎯 About This Project

This project recreates and extends the concepts from OpenAI's famous hide-and-seek experiment where AI agents developed complex strategies through reinforcement learning, including:

- **Box Surfing** - Agents learned to use boxes as vehicles
- **Ramp Building** - Construction of tools to reach new areas
- **Team Coordination** - Emergent cooperative behaviors
- **Strategic Thinking** - Long-term planning and adaptation

## 🎮 Game Modes

### 1. 🤖 **AI vs AI**
Watch multiple neural networks compete and evolve in real-time:
- Multiple AI agents learn through reinforcement learning
- Evolutionary algorithms improve strategies over generations
- Real-time visualization of learning progress
- Emergent behaviors and surprising tactics

### 2. 🙋 **Player Hide vs AI Seek**
Test your hiding skills against intelligent AI:
- You play as the hider
- AI seeker uses reinforcement learning to hunt you
- AI learns from your strategies and adapts
- Progressive difficulty as AI improves

### 3. 🔍 **Player Seek vs AI Hide**
Hunt intelligent AI agents that learn to evade:
- You play as the seeker
- AI hiders develop creative escape strategies
- AI learns optimal hiding spots and patterns
- Track AI learning progress in real-time

## 🧠 AI Architecture

### Neural Network Design
- **Input Layer**: Position, health, visible entities, time, meta-data (20 neurons)
- **Hidden Layers**: 64 → 32 → 16 neurons with ReLU activation
- **Output Layer**: 11 possible actions with softmax activation

### Learning Algorithm
- **Reinforcement Learning**: Q-learning with experience replay
- **Exploration**: Epsilon-greedy strategy with decay
- **Memory**: Experience replay buffer (10,000 experiences)
- **Evolution**: Genetic algorithm for population improvement

### Action Space
1. Movement in 8 directions
2. Stay in place
3. Hide/Seek behaviors
4. Environmental interactions

## 🚀 Features

### AI Capabilities
- **Vision System**: 200-unit detection range
- **Memory**: Position history and entity tracking
- **Strategy Evolution**: Learning from success/failure
- **Adaptation**: Dynamic difficulty adjustment

### Visual Features
- **Real-time Learning Visualization**: See AI decision-making
- **Statistics Dashboard**: Track learning progress
- **Behavior Analysis**: Understand emergent strategies
- **Replay System**: Review interesting matches

### Technical Features
- **Modular Architecture**: Easy to extend and modify
- **Save/Load AI Brains**: Preserve learned behaviors
- **Multi-threading**: Efficient AI computation
- **Debug Tools**: Comprehensive AI debugging interface

## 📁 Project Structure

```
hide_and_seek_project/
├── scenes/              # Game scenes
│   ├── main_menu.tscn
│   ├── game_arena.tscn
│   ├── player_character.tscn
│   └── ai_character.tscn
├── scripts/             # Game logic
│   ├── game_manager.gd
│   ├── main_menu.gd
│   ├── player_controller.gd
│   └── ui_manager.gd
├── ai/                  # AI systems
│   ├── neural_network.gd
│   ├── ai_agent.gd
│   ├── reinforcement_learning.gd
│   └── genetic_algorithm.gd
├── ui/                  # User interface
│   ├── hud.tscn
│   ├── statistics_panel.tscn
│   └── debug_overlay.tscn
├── levels/              # Game arenas
│   ├── hide_and_seek_arena.tscn
│   ├── complex_environment.tscn
│   └── training_grounds.tscn
└── assets/              # Art and audio
    ├── sprites/
    ├── sounds/
    └── materials/
```

## 🎮 Controls

### Player Controls
- **WASD/Arrow Keys**: Movement
- **Shift**: Sprint
- **Space**: Interact/Hide
- **Tab**: Toggle AI Debug View
- **R**: Restart Round
- **ESC**: Pause Menu

### AI Debug Controls
- **F1**: Toggle AI Vision Display
- **F2**: Show Decision Trees
- **F3**: Learning Statistics
- **F4**: Save AI Brains
- **F5**: Load AI Brains

## 🔧 Configuration

### AI Parameters (project.godot)
```ini
[ai]
learning_rate=0.001
exploration_rate=0.1
memory_size=10000
batch_size=32
update_frequency=4
target_update_frequency=1000
```

### Game Parameters
```ini
[game]
default_round_time=300.0
hide_seek_distance=50.0
spawn_protection_time=3.0
max_ai_agents=10
```

## 🚀 Getting Started

### Prerequisites
- **Godot 4.6** or newer
- **Python 3.8+** (for advanced AI training scripts)
- **Git** for version control

### Installation
1. Clone the repository:
```bash
git clone https://github.com/GulyaTV/hide-and-seek-ai.git
cd hide-and-seek-ai
```

2. Open in Godot:
- Launch Godot 4.6
- Click "Import" → select project folder
- Open and run `main_menu.tscn`

### First Run
1. Start with **AI vs AI** mode to see baseline behaviors
2. Try **Player Hide vs AI Seek** to experience AI hunting
3. Experiment with **Player Seek vs AI Hide** to test AI evasion
4. Monitor AI learning progress in the statistics panel

## 🧪 Experimentation

### Training AI Agents
```gdscript
# Start training session
var game_manager = $GameManager
game_manager.start_training_mode(
    generations=100,
    population_size=50,
    mutation_rate=0.1
)
```

### Analyzing Behaviors
- Use debug overlay to see AI decision-making
- Export training data for analysis
- Record interesting matches for review
- Compare different AI architectures

### Custom Scenarios
Create custom levels and scenarios:
```gdscript
# Create custom training environment
var custom_level = LevelBuilder.new()
custom_level.add_obstacles([
    {"type": "box", "position": Vector2(100, 100), "size": Vector2(50, 50)},
    {"type": "ramp", "position": Vector2(200, 0), "angle": 45}
])
```

## 📊 Research Applications

This project can be used for:
- **Reinforcement Learning Research**: Test new algorithms
- **Multi-agent Systems**: Study cooperation and competition
- **Emergent Behavior**: Observe complex strategy development
- **Educational Purposes**: Teach AI concepts interactively
- **Game AI Development**: Benchmark AI systems

## 🤝 Contributing

We welcome contributions! Areas of interest:
- **New AI Architectures**: Transformers, attention mechanisms
- **Complex Environments**: More interactive objects
- **Visualization Tools**: Better AI behavior analysis
- **Performance Optimization**: Faster training and inference
- **Research Integration**: Connect to ML frameworks

### Development Setup
1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push branch: `git push origin feature/amazing-feature`
5. Open Pull Request

## 📈 Performance Metrics

### AI Learning Progress
- **Convergence Rate**: Generations to reach stable behavior
- **Win Rate**: Success rate in different scenarios
- **Strategy Diversity**: Variety of emergent behaviors
- **Adaptation Speed**: How quickly AI adapts to new strategies

### System Performance
- **FPS**: 60+ FPS with 10+ AI agents
- **Memory Usage**: <500MB for standard scenarios
- **Training Speed**: 1000+ episodes/minute
- **Response Time**: <16ms AI decision-making

## 🐛 Troubleshooting

### Common Issues
- **AI Not Learning**: Check learning rate and reward structure
- **Poor Performance**: Reduce AI count or lower resolution
- **Crashes**: Verify Godot 4.6 compatibility
- **Memory Leaks**: Monitor experience replay buffer size

### Debug Mode
Enable comprehensive debugging:
```gdscript
# Enable debug mode
Debug.enabled = true
Debug.show_ai_decisions = true
Debug.log_experiences = true
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **OpenAI** for the original hide-and-seek experiment inspiration
- **Godot Engine** for the excellent game development framework
- **Reinforcement Learning Community** for algorithms and techniques
- **Contributors** who help improve this project

## 📞 Contact

- **Project Maintainer**: [Your Name]
- **Email**: [your.email@example.com]
- **Discord**: [Server Link]
- **Twitter**: [@yourhandle]

---

**Made with ❤️ and 🧠 for AI research and gaming innovation!**

*Watch as artificial intelligence discovers creative ways to play hide and seek - just like humans do!* 🎮🤖
