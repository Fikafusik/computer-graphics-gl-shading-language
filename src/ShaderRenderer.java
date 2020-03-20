
import com.jogamp.opengl.GL;
import com.jogamp.opengl.GL2;
import com.jogamp.opengl.GLAutoDrawable;
import com.jogamp.opengl.GLEventListener;
import com.jogamp.opengl.util.texture.Texture;
import com.jogamp.opengl.util.texture.TextureIO;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.util.Scanner;

public class ShaderRenderer implements GLEventListener {
    private int resolutionLocation;

    private int rotateAngleLocation;
    private int roughnessLocation;
    private int refractionLocation;

    private float rotateAngle = 0.0f;
    private float rotateAngleDelta = 0.02f;
    private float roughness = 0.6f;
    private float refraction = 1.31f;

    public void setRotateAngleDelta(float rotateAngleDelta) {
        this.rotateAngleDelta = rotateAngleDelta;
    }

    public void setRoughness(float roughness) {
        this.roughness = roughness;
    }

    public void setRefraction(float refraction) {
        this.refraction = refraction;
    }

    ShaderRenderer() {

    }

    private static String readFromStream(InputStream ins) throws IOException {
        if (ins == null) {
            throw new IOException("Could not read from stream.");
        }
        StringBuilder builder = new StringBuilder();
        Scanner scanner = new Scanner(ins);
        try {
            while (scanner.hasNextLine()) {
                builder.append(scanner.nextLine());
                builder.append('\n');
            }
        } finally {
            scanner.close();
        }

        return builder.toString();
    }

    @Override
    public void init(GLAutoDrawable glAutoDrawable) {
        final GL2 gl = glAutoDrawable.getGL().getGL2();

        int fragmentShader = gl.glCreateShader(GL2.GL_FRAGMENT_SHADER);

        try {
        gl.glShaderSource(fragmentShader, 1, new String[] {
                readFromStream(ShaderRenderer.class.getResourceAsStream("Ice.glsl"))
        }, null, 0);
        } catch (IOException e) {
            System.out.println(e.getMessage());
        }

        gl.glCompileShader(fragmentShader);

        int shaderProgram = gl.glCreateProgram();
        gl.glAttachShader(shaderProgram, fragmentShader);
        gl.glLinkProgram(shaderProgram);
        gl.glValidateProgram(shaderProgram);
        gl.glUseProgram(shaderProgram);

        gl.glUniform1i(gl.glGetUniformLocation(shaderProgram, "uniformIce"), 0);
        gl.glUniform1i(gl.glGetUniformLocation(shaderProgram, "uniformSnow"), 1);

        resolutionLocation = gl.glGetUniformLocation(shaderProgram, "uniformResolution");

        rotateAngleLocation = gl.glGetUniformLocation(shaderProgram, "uniformRotateAngle");
        roughnessLocation = gl.glGetUniformLocation(shaderProgram, "uniformRoughness");
        refractionLocation = gl.glGetUniformLocation(shaderProgram, "uniformRefraction");


        try {
            Texture iceTexture = TextureIO.newTexture(new File("perlin-noise2.jpg"), false);
            Texture snowTexture = TextureIO.newTexture(new File("texture3.jpg"), false);

            gl.glActiveTexture(GL.GL_TEXTURE0);
            gl.glBindTexture(GL.GL_TEXTURE_2D, iceTexture.getTextureObject());
            gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_REPEAT);
            gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_REPEAT);

            gl.glActiveTexture(GL.GL_TEXTURE1);
            gl.glBindTexture(GL.GL_TEXTURE_2D, snowTexture.getTextureObject());
            gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_S, GL.GL_REPEAT);
            gl.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_WRAP_T, GL.GL_REPEAT);

        } catch (IOException e) {
            System.out.println(e.getMessage());
        }

    }

    @Override
    public void dispose(GLAutoDrawable glAutoDrawable) {

    }

    @Override
    public void display(GLAutoDrawable glAutoDrawable) {
        final GL2 gl = glAutoDrawable.getGL().getGL2();

        gl.glClear(GL.GL_COLOR_BUFFER_BIT | GL.GL_DEPTH_BUFFER_BIT);

        gl.glUniform1f(rotateAngleLocation, rotateAngle);
        gl.glUniform1f(roughnessLocation, roughness);
        gl.glUniform1f(refractionLocation, refraction);

        rotateAngle += rotateAngleDelta;

        gl.glBegin(GL2.GL_QUADS);
        gl.glVertex2d(-1.0, 1.0);
        gl.glVertex2d(-1.0, -1.0);
        gl.glVertex2d(1.0, -1.0);
        gl.glVertex2d(1.0, 1.0);

        gl.glEnd();
    }

    @Override
    public void reshape(GLAutoDrawable glAutoDrawable, int x, int y, int width, int height) {
        final GL2 gl = glAutoDrawable.getGL().getGL2();

        gl.glUniform3f(resolutionLocation, width, height, 1.0f);

    }
}
