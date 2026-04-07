GAME = Dama::Game.new do
  settings resolution: [800, 600], title: "Checkers"
  start_scene TitleScene
end
