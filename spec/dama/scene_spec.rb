RSpec.describe Dama::Scene do
  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 0
      attribute :y, default: 0
    end
  end

  let(:player_class) do
    tc = transform_class
    stub_const("Player", Class.new(Dama::Node) do
      component tc, as: :transform, x: 50, y: 50
      attribute :name, default: "Hero"
    end)
  end

  let(:registry) { Dama::Registry.new }

  before do
    registry.register(klass: player_class, category: :node)
  end

  describe "lifecycle" do
    let(:scene_class) do
      pc = player_class
      Class.new(described_class) do
        compose do
          add pc, as: :hero
        end

        enter do
          hero.name = "Entered"
        end
      end
    end

    it "compose builds the scene graph with named accessors" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      expect(scene.hero.node).to be_a(player_class)
      expect(scene.hero.name).to eq("Hero")
    end

    it "enter modifies scene state via named accessor" do
      scene = scene_class.new(registry:)
      scene.perform_compose
      scene.perform_enter

      expect(scene.hero.name).to eq("Entered")
    end
  end

  describe "queries" do
    let(:slime_class) do
      stub_const("Slime", Class.new(Dama::Node) do
        attribute :name, default: "Slime"
      end)
    end

    let(:scene_class) do
      pc = player_class
      sc = slime_class
      Class.new(described_class) do
        compose do
          add pc, as: :hero
          add sc, as: :s1
          add sc, as: :s2
        end
      end
    end

    before do
      registry.register(klass: slime_class, category: :node)
    end

    it "#all returns nodes by class" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      expect(scene.all(slime_class).length).to eq(2)
      expect(scene.all(player_class).length).to eq(1)
    end

    it "#each iterates over nodes of a class" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      names = []
      scene.each(slime_class) { |n| names << n.name }
      expect(names).to eq(%w[Slime Slime])
    end

    it "#remove removes a node" do
      scene = scene_class.new(registry:)
      scene.perform_compose
      scene.remove(:s1)

      expect(scene.all(slime_class).length).to eq(1)
    end
  end

  describe "#switch_to" do
    it "calls the scene_switcher with the scene class" do
      called_with = nil
      switcher = ->(scene_class) { called_with = scene_class }

      scene = described_class.new(registry:, scene_switcher: switcher)
      scene.switch_to(String)

      expect(called_with).to eq(String)
    end

    it "does not raise when scene_switcher is nil" do
      scene = described_class.new(registry:)
      expect { scene.switch_to(String) }.not_to raise_error
    end
  end

  describe "#add (dynamic, at runtime)" do
    let(:label_class) do
      stub_const("Label", Class.new(Dama::Node) do
        attribute :text, default: ""
      end)
    end

    let(:scene_class) do
      Class.new(described_class) do
        compose {}
      end
    end

    it "adds a node by class with props" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      scene.add(label_class, as: :msg, text: "Hello")

      expect(scene.msg.text).to eq("Hello")
    end

    it "adds a pre-built instance" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      instance = label_class.new(text: "Pre-built")
      scene.add(instance, as: :existing)

      expect(scene.existing.text).to eq("Pre-built")
    end

    it "makes the node queryable by class" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      scene.add(label_class, as: :lbl)

      expect(scene.all(label_class).length).to eq(1)
    end

    it "supports tags" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      scene.add(label_class, as: :lbl, tags: [:ui])

      expect(scene.by_tag(:ui).length).to eq(1)
    end

    it "added nodes can be removed" do
      scene = scene_class.new(registry:)
      scene.perform_compose

      scene.add(label_class, as: :temp)
      scene.remove(:temp)

      expect(scene.all(label_class).length).to eq(0)
    end

    it "adds to a specific group" do
      group_scene_class = Class.new(described_class) do
        compose do
          group :overlay do
          end
        end
      end

      scene = group_scene_class.new(registry:)
      scene.perform_compose

      scene.add(label_class, as: :toast, group: :overlay)

      expect(scene.toast.text).to eq("")
      expect(scene.all(label_class).length).to eq(1)
    end
  end

  describe ".sound + #play" do
    include_context "with headless backend"

    it "declares sounds at class level and loads them during compose" do
      Dir.mktmpdir do |dir|
        wav_path = File.join(dir, "beep.wav")
        write_minimal_wav(wav_path)

        sc = Class.new(Dama::Scene) do
          sound :beep, path: wav_path
          compose {}
        end

        scene = sc.new(registry:, backend:)
        scene.perform_compose

        expect { scene.play(:beep) }.not_to raise_error
      end
    end

    it "silently does nothing when no sounds are declared" do
      sc = Class.new(Dama::Scene) { compose {} }
      scene = sc.new(registry:)
      scene.perform_compose

      expect { scene.play(:nonexistent) }.not_to raise_error
    end

    it "skips loading when no backend is provided" do
      Dir.mktmpdir do |dir|
        wav_path = File.join(dir, "beep.wav")
        write_minimal_wav(wav_path)

        sc = Class.new(Dama::Scene) do
          sound :beep, path: wav_path
          compose {}
        end

        # No backend — sounds are declared but cannot be loaded.
        scene = sc.new(registry:)
        scene.perform_compose

        expect { scene.play(:beep) }.not_to raise_error
      end
    end
  end

  describe "camera in compose block" do
    it "enables camera when declared in compose" do
      sc = Class.new(Dama::Scene) do
        compose { camera viewport_width: 640, viewport_height: 480 }
      end

      scene = sc.new(registry:)
      scene.perform_compose

      expect(scene.camera).to be_a(Dama::Camera)
      expect(scene.camera.viewport_width).to eq(640.0)
      expect(scene.camera.viewport_height).to eq(480.0)
    end
  end
end
