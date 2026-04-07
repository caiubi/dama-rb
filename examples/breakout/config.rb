GAME = Dama::Game.new do
  settings resolution: [800, 600], title: "Breakout"
  start_scene BreakoutScene
end
