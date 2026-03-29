require "fileutils"

module Dama
  class Cli
    # Generates a new game project in the current directory.
    # Creates the standard directory structure with starter files
    # for a playable game: a red circle moveable with arrow keys.
    class NewProject
      FILE_PERMISSIONS = {
        true => 0o755,
        false => 0o644,
      }.freeze

      def self.run
        new.generate
      end

      def generate
        puts "Creating new dama game project..."

        TEMPLATES.each do |path, template|
          write_template(path:, template:)
        end

        create_directory("assets")

        puts "\nDone! Run bin/dama to start your game."
      end

      private

      def write_template(path:, template:)
        full_path = File.join(Dir.pwd, path)
        return puts("  exists  #{path}") if File.exist?(full_path)

        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, template.fetch(:content))
        FileUtils.chmod(FILE_PERMISSIONS.fetch(template.fetch(:executable)), full_path)
        puts "  create  #{path}"
      end

      def create_directory(name)
        return puts("  exists  #{name}/") if File.directory?(name)

        FileUtils.mkdir_p(name)
        puts "  create  #{name}/"
      end

      TEMPLATES = {
        "config.rb" => {
          content: <<~RUBY,
            GAME = Dama::Game.new do
              settings resolution: [800, 600], title: "My Game"
              start_scene MainScene
            end
          RUBY
          executable: false,
        },
        "bin/dama" => {
          content: <<~RUBY,
            #!/usr/bin/env ruby
            require "bundler/setup"
            require "dama"

            Dama.boot(root: File.expand_path("..", __dir__))
          RUBY
          executable: true,
        },
        "game/components/transform.rb" => {
          content: <<~RUBY,
            class Transform < Dama::Component
              attribute :x, default: 0.0
              attribute :y, default: 0.0
            end
          RUBY
          executable: false,
        },
        "game/nodes/player.rb" => {
          content: <<~RUBY,
            class Player < Dama::Node
              component Transform, as: :transform, x: 400.0, y: 300.0

              draw do
                circle(transform.x, transform.y, 20.0, color: Dama::Colors::RED)
              end
            end
          RUBY
          executable: false,
        },
        "game/scenes/main_scene.rb" => {
          content: <<~RUBY,
            class MainScene < Dama::Scene
              compose do
                add Player, as: :hero
              end

              update do |dt, input|
                speed = 200.0

                hero.transform.x += speed * dt if input.right?
                hero.transform.x -= speed * dt if input.left?
                hero.transform.y += speed * dt if input.down?
                hero.transform.y -= speed * dt if input.up?
              end
            end
          RUBY
          executable: false,
        },
      }.freeze
    end
  end
end
