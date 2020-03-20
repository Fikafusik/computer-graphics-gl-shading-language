
import com.jogamp.opengl.awt.GLCanvas;
import com.jogamp.opengl.util.FPSAnimator;

import javax.swing.*;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

public class GUI extends JFrame {

    private static final int DEFAULT_WINDOW_WIDTH = 800;
    private static final int DEFAULT_WINDOW_HEIGHT = 600;
    private static final int FRAMES_PER_SECOND = 60;

    private final FPSAnimator animator;
    private final MusicThread musician = new MusicThread("cubic.wav");

    public GUI() {
        setDefaultCloseOperation(EXIT_ON_CLOSE);
        setTitle("GONE.Fludd - КУБИК ЛЬДА");
        setSize(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);

        ShaderRenderer shaderRenderer = new ShaderRenderer();

        GLCanvas shaderCanvas = new GLCanvas();
        shaderCanvas.addGLEventListener(shaderRenderer);

        animator = new FPSAnimator(shaderCanvas, FRAMES_PER_SECOND);

        JLabel labelRoughness = new JLabel("Roughness");

        JLabel labelRotateAngleDelta = new JLabel("Rotate angle delta");

        FloatJSlider sliderRotateAngleDelta = new FloatJSlider(0.00f, 0.05f, 0.02f, 100);
        sliderRotateAngleDelta.addChangeListener(e -> shaderRenderer.setRotateAngleDelta(sliderRotateAngleDelta.getFloatValue()));

        FloatJSlider sliderRoughness = new FloatJSlider(0.0f, 2.0f, 0.6f, 100);
        sliderRoughness.addChangeListener(e -> shaderRenderer.setRoughness(sliderRoughness.getFloatValue()));

        JLabel labelRefraction = new JLabel("Refraction");

        FloatJSlider sliderRefraction = new FloatJSlider(1.0f, 3.0f,1.31f, 100);
        sliderRefraction.addChangeListener(e -> shaderRenderer.setRefraction(sliderRefraction.getFloatValue()));

        JPanel panelShaderProperties = new JPanel();
        panelShaderProperties.setLayout(new BoxLayout(panelShaderProperties, BoxLayout.Y_AXIS));
        panelShaderProperties.add(labelRotateAngleDelta);
        panelShaderProperties.add(sliderRotateAngleDelta);
        panelShaderProperties.add(labelRoughness);
        panelShaderProperties.add(sliderRoughness);
        panelShaderProperties.add(labelRefraction);
        panelShaderProperties.add(sliderRefraction);

        JSplitPane splitPaneGUI = new JSplitPane();
        splitPaneGUI.setLeftComponent(panelShaderProperties);
        splitPaneGUI.setRightComponent(shaderCanvas);

        add(splitPaneGUI);

        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                super.windowClosing(e);
                animator.stop();
                musician.interrupt();
            }
        });
    }

    public void run() {
        setVisible(true);
        animator.start();
    }
}
