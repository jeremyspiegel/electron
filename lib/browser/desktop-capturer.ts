import { EventEmitter } from 'events'

const { createDesktopCapturer } = process.electronBinding('desktop_capturer')

const deepEqual = (a: ElectronInternal.GetSourcesOptions, b: ElectronInternal.GetSourcesOptions) => JSON.stringify(a) === JSON.stringify(b)

let currentlyRunning: {
  options: ElectronInternal.GetSourcesOptions;
  getSources: Promise<ElectronInternal.GetSourcesResult[]>;
}[] = []

export const getSources = (event: Electron.IpcMainEvent, options: ElectronInternal.GetSourcesOptions) => {
  for (const running of currentlyRunning) {
    if (deepEqual(running.options, options)) {
      // If a request is currently running for the same options
      // return that promise
      return running.getSources
    }
  }

  const getSources = new Promise<ElectronInternal.GetSourcesResult[]>((resolve, reject) => {
    const stopRunning = () => {
      // Remove from currentlyRunning once we resolve or reject
      currentlyRunning = currentlyRunning.filter(running => running.options !== options)
    }

    const emitter = new EventEmitter()

    emitter.once('error', (event, error: string) => {
      stopRunning()
      reject(error)
    })

    emitter.once('finished', (event, sources: Electron.DesktopCapturerSource[], fetchWindowIcons: boolean) => {
      stopRunning()
      resolve(sources.map(source => ({
        id: source.id,
        name: source.name,
        thumbnail: source.thumbnail.toDataURL(),
        display_id: source.display_id,
        appIcon: (fetchWindowIcons && source.appIcon) ? source.appIcon.toDataURL() : null
      })))
    })

    let capturer: NodeJS.DesktopCapturerBinding | null = createDesktopCapturer()

    capturer.emit = emitter.emit.bind(emitter)
    capturer.startHandling(options.captureWindow, options.captureScreen, options.thumbnailSize, options.fetchWindowIcons)

    // If the WebContents is destroyed before receiving result, just remove the
    // reference to emit and the capturer itself so that it never dispatches
    // back to the renderer
    event.sender.once('destroyed', () => {
      capturer!.emit = () => false
      capturer = null
      stopRunning()
    })
  })

  currentlyRunning.push({
    options,
    getSources
  })

  return getSources
}
