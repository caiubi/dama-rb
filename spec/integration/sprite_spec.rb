RSpec.describe "Sprite/texture rendering end-to-end" do
  include_context "with headless backend"

  let(:test_png_bytes) { create_test_png }

  describe "texture loading and rendering" do
    it "loads a texture from bytes and renders a sprite" do
      handle = backend.load_texture(bytes: test_png_bytes)
      expect(handle).to be > 0

      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      backend.draw_sprite(texture_handle: handle, x: 10.0, y: 10.0, w: 44.0, h: 44.0)
      backend.end_frame

      expect(backend.frame_count).to eq(1)
      backend.unload_texture(handle:)
    end

    it "loads a texture from a file path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.png")
        File.binwrite(path, test_png_bytes)

        handle = backend.load_texture_file(path:)
        expect(handle).to be > 0
        backend.unload_texture(handle:)
      end
    end

    it "raises when loading invalid image data" do
      expect { backend.load_texture(bytes: "not a png") }.to raise_error(RuntimeError)
    end

    it "renders shapes and sprites together" do
      handle = backend.load_texture(bytes: test_png_bytes)

      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      backend.draw_rect(x: 0.0, y: 0.0, w: 20.0, h: 20.0, r: 1.0, g: 0.0, b: 0.0, a: 1.0)
      backend.draw_sprite(texture_handle: handle, x: 30.0, y: 30.0, w: 30.0, h: 30.0)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "mixed.png")
        backend.screenshot(output_path: path)
        expect(File.exist?(path)).to be(true)
      end

      backend.unload_texture(handle:)
    end
  end

  describe "DrawContext#sprite" do
    let(:sprite_node_class) do
      Class.new(Dama::Node) do
        attribute :texture_handle, default: 0
        draw do
          sprite(texture_handle, 10, 10, 44, 44)
        end
      end
    end

    it "renders a sprite via the DrawContext DSL" do
      handle = backend.load_texture(bytes: test_png_bytes)
      node = sprite_node_class.new(texture_handle: handle)

      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context = Dama::Node::DrawContext.new(node:, backend:)
      context.instance_eval(&sprite_node_class.draw_block)
      backend.end_frame

      backend.unload_texture(handle:)
    end
  end

  describe "AssetCache ref counting" do
    let(:asset_cache) { Dama::AssetCache.new(backend:) }

    it "shares the same handle for the same path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.png")
        File.binwrite(path, test_png_bytes)

        handle1 = asset_cache.acquire(path:)
        handle2 = asset_cache.acquire(path:)

        expect(handle1).to eq(handle2)
        expect(asset_cache.handle_for(path:)).to eq(handle1)

        # First release decrements ref count but keeps texture.
        asset_cache.release(path:)
        expect(asset_cache.handle_for(path:)).to eq(handle1)

        # Second release unloads from GPU.
        asset_cache.release(path:)
        expect(asset_cache.handle_for(path:)).to be_nil
      end
    end

    it "release_all clears everything" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.png")
        File.binwrite(path, test_png_bytes)

        asset_cache.acquire(path:)
        asset_cache.release_all
        expect(asset_cache.handle_for(path:)).to be_nil
      end
    end

    it "release on unknown path does nothing" do
      expect { asset_cache.release(path: "/nonexistent") }.not_to raise_error
    end
  end

  describe "Node texture DSL with scene lifecycle" do
    let(:textured_node_class) do
      png_path = @png_path
      stub_const("TexturedNode", Class.new(Dama::Node) do
        texture :my_tex, path: png_path
        draw do
          sprite(my_tex, 10, 10, 44, 44)
        end
      end)
    end

    let(:registry) { Dama::Registry.new }
    let(:asset_cache) { Dama::AssetCache.new(backend:) }

    it "loads textures during compose and unloads on remove" do
      Dir.mktmpdir do |dir|
        @png_path = File.join(dir, "tex.png")
        File.binwrite(@png_path, test_png_bytes)

        registry.register(klass: textured_node_class, category: :node)

        scene_class = Class.new(Dama::Scene) do
          compose do
            add TexturedNode, as: :sprite1
            add TexturedNode, as: :sprite2
          end
        end

        scene = scene_class.new(registry:, asset_cache:)
        scene.perform_compose

        # Both nodes share the same texture handle.
        handle = asset_cache.handle_for(path: @png_path)
        expect(handle).to be > 0
        expect(scene.sprite1.my_tex).to eq(handle)
        expect(scene.sprite2.my_tex).to eq(handle)

        # Render a frame to verify it works.
        backend.begin_frame
        backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
        scene.perform_draw(backend:)
        backend.end_frame

        # Remove one node: texture still cached (ref count > 0).
        scene.remove(:sprite1)
        expect(asset_cache.handle_for(path: @png_path)).to eq(handle)

        # Remove second node: texture released (ref count = 0).
        scene.remove(:sprite2)
        expect(asset_cache.handle_for(path: @png_path)).to be_nil
      end
    end
  end

  private

  def create_test_png
    backend.clear(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "gen.png")
      backend.screenshot(output_path: path)
      File.binread(path)
    end
  end
end
