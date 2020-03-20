
import javax.sound.sampled.*;
import java.io.File;
import java.io.IOException;

public class MusicThread extends Thread {

    private final String filename;

    MusicThread(String filename) {
        super();

        this.filename = filename;
        start();
    }

    public void run() {
        try {
            File soundFile = new File(filename);
            AudioInputStream ais = AudioSystem.getAudioInputStream(soundFile);

            Clip clip = AudioSystem.getClip();
            clip.open(ais);
            clip.setFramePosition(0);
            clip.start();

            Thread.sleep(clip.getMicrosecondLength() / 1000);

            clip.stop();
            clip.close();
        } catch (IOException | UnsupportedAudioFileException | LineUnavailableException exc) {
            exc.printStackTrace();
        } catch (InterruptedException exc) {

        }

    }
}
