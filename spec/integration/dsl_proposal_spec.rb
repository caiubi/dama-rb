RSpec.describe "Full DSL end-to-end via headless backend" do
  let(:transform_class) do
    Class.new(Dama::Component) do
      attribute :x, default: 0.0
      attribute :y, default: 0.0
      attribute :speed, default: 100.0
    end
  end

  let(:player_class) do
    tc = transform_class
    stub_const("Player", Class.new(Dama::Node) do
      component tc, as: :transform, x: 50.0, y: 50.0, speed: 100.0
      attribute :name, default: "Hero"

      draw do
        triangle(
          transform.x, transform.y - 10,
          transform.x - 10, transform.y + 10,
          transform.x + 10, transform.y + 10,
          r: 1.0, g: 0.0, b: 0.0, a: 1.0
        )
      end
    end)
  end

  let(:marker_class) do
    stub_const("Marker", Class.new(Dama::Node) do
      attribute :label, default: "?"

      draw do
        circle(32, 32, 10, r: 0.0, g: 1.0, b: 0.0, a: 1.0)
      end
    end)
  end

  let(:scene_with_update_class) do
    pc = player_class
    mc = marker_class
    Class.new(Dama::Scene) do
      compose do
        add pc, as: :hero, tags: [:player]

        group :ui do
          add mc, as: :hud, label: "HP"
        end

        add mc, as: :m1, tags: [:enemy], label: "E1"
        add mc, as: :m2, tags: [:enemy], label: "E2"
      end

      enter do
        hero.name = "Ready"
      end

      # Uses named accessor `hero` and component accessor `transform`.
      update do |dt, input|
        hero.transform.x += hero.transform.speed * dt if input.right?
        hero.transform.x -= hero.transform.speed * dt if input.left?
      end
    end
  end

  let(:registry) { Dama::Registry.new }
  let(:backend) { Dama::Backend::Native.new }
  let(:configuration) { Dama::Configuration.new(width: 128, height: 128, headless: true) }

  before do
    backend.initialize_engine(configuration:)
    registry.register(klass: player_class, category: :node)
    registry.register(klass: marker_class, category: :node)
  end

  after do
    backend.shutdown
  end

  it "compose + enter + update + draw full lifecycle" do
    scene = scene_with_update_class.new(registry:)
    scene.perform_compose
    scene.perform_enter

    expect(scene.hero.name).to eq("Ready")

    input = Dama::Input.new(backend:)
    scene.perform_update(delta_time: 0.016, input:)

    backend.begin_frame
    backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
    scene.perform_draw(backend:)
    backend.end_frame

    expect(backend.frame_count).to eq(1)
  end

  it "queries by_tag and by_path using named accessors" do
    scene = scene_with_update_class.new(registry:)
    scene.perform_compose

    enemies = scene.by_tag(:enemy)
    expect(enemies.length).to eq(2)
    expect(enemies.map(&:id)).to contain_exactly(:m1, :m2)

    hud = scene.ref!("ui/hud")
    expect(hud.label).to eq("HP")
  end

  it "Input and KeyboardState work in headless mode" do
    input = Dama::Input.new(backend:)

    expect(input.left?).to be(false)
    expect(input.right?).to be(false)
    expect(input.up?).to be(false)
    expect(input.down?).to be(false)
    expect(input.space?).to be(false)
    expect(input.escape?).to be(false)
  end

  it "Input mouse methods and update work in headless mode" do
    input = Dama::Input.new(backend:)
    input.update

    expect(input.mouse_x).to eq(0.0)
    expect(input.mouse_y).to eq(0.0)
    expect(input.mouse_clicked?).to be(false)
  end

  it "captures a screenshot after drawing shapes via DSL" do
    scene = scene_with_update_class.new(registry:)
    scene.perform_compose

    backend.begin_frame
    backend.clear(r: 0.1, g: 0.1, b: 0.3, a: 1.0)
    scene.perform_draw(backend:)
    backend.end_frame

    Dir.mktmpdir do |dir|
      path = File.join(dir, "dsl_scene.png")
      backend.screenshot(output_path: path)
      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 100
    end
  end
end
