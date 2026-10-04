package au.jly.e60updater

import android.app.job.JobParameters
import android.app.job.JobService

/** Runs one [Updater] pass on a worker thread; the job keeps the process alive meanwhile. */
class UpdateJobService : JobService() {
    @Volatile private var stopped = false

    override fun onStartJob(params: JobParameters): Boolean {
        running = true
        stopped = false
        Thread({
            try {
                val interactive = params.extras.getBoolean(Trigger.EXTRA_INTERACTIVE, false)
                val outcome = Updater(applicationContext, interactive) { stopped }.run()
                outcome.notify?.let { Notifier.show(applicationContext, it) }
            } finally {
                running = false
                jobFinished(params, false)
            }
        }, "e60-update").start()
        return true // work continues on the thread
    }

    override fun onStopJob(params: JobParameters): Boolean {
        stopped = true
        running = false
        return false // the next Wi-Fi join or "Check now" retries; downloads stay cached
    }

    companion object {
        @Volatile var running = false
    }
}
