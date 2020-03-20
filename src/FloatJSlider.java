
import javax.swing.*;

public class FloatJSlider extends JSlider {

    private final float minimum;
    private final float maximum;
    private final float scale;

    public FloatJSlider(float min, float max, float value, int scale) {
        super(0, scale, (int)(scale * (value - min) / (max - min)));

        this.minimum = min;
        this.maximum = max;
        this.scale = scale;
    }

    public float getFloatValue() {
        return (minimum + (maximum - minimum) * getValue() / scale);
    }
}
