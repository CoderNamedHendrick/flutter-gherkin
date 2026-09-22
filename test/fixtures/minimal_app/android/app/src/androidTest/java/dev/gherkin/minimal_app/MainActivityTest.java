package dev.gherkin.minimal_app;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner runner = (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        runner.setUp(MainActivity.class);
        runner.waitForPatrolAppService();
        return runner.listDartTests();
    }
    private final String testName;
    public MainActivityTest(String testName) { this.testName = testName; }
    @Test
    public void runDartTest() {
        PatrolJUnitRunner runner = (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        runner.runDartTest(testName);
    }
}
