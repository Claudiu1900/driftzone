import {
    OrthographicCamera,
    Scene,
    WebGLRenderTarget,
    LinearFilter,
    NearestFilter,
    RGBAFormat,
    UnsignedByteType,
    CfxTexture,
    ShaderMaterial,
    PlaneBufferGeometry,
    Mesh,
    WebGLRenderer
} from '@citizenfx/three';

class ScreenshotRequest {
    encoding: 'jpg' | 'png' | 'webp';
    quality: number;
    headers: any;
    correlation: string;
    resultURL: string;
    targetURL: string;
    targetField: string;
}

function dataURItoBlob(dataURI: string) {
    const byteString = atob(dataURI.split(',')[1]);
    const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);
    for (let i = 0; i < byteString.length; i++) ia[i] = byteString.charCodeAt(i);
    return new Blob([ab], { type: mimeString });
}

class DriftzoneScreenshotUI {
    renderer: any;
    rtTexture: any;
    sceneRTT: any;
    cameraRTT: any;
    material: any;
    request: ScreenshotRequest | null = null;

    initialize() {
        window.addEventListener('message', event => {
            if (event.data && event.data.request) this.request = event.data.request;
        });
        window.addEventListener('resize', () => this.resize());
        this.createRenderer();
        this.animate = this.animate.bind(this);
        requestAnimationFrame(this.animate);
    }

    createRenderer() {
        const width = Math.max(1, window.innerWidth);
        const height = Math.max(1, window.innerHeight);

        this.cameraRTT = new OrthographicCamera(width / -2, width / 2, height / 2, height / -2, -10000, 10000);
        this.cameraRTT.position.z = 100;
        this.sceneRTT = new Scene();
        this.rtTexture = new WebGLRenderTarget(width, height, { minFilter: LinearFilter, magFilter: NearestFilter, format: RGBAFormat, type: UnsignedByteType });

        const gameTexture: any = new CfxTexture();
        gameTexture.needsUpdate = true;

        this.material = new ShaderMaterial({
            uniforms: { tDiffuse: { value: gameTexture } },
            vertexShader: `
                varying vec2 vUv;
                void main() {
                    vUv = vec2(uv.x, 1.0 - uv.y);
                    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
                }
            `,
            fragmentShader: `
                varying vec2 vUv;
                uniform sampler2D tDiffuse;
                void main() {
                    gl_FragColor = texture2D(tDiffuse, vUv);
                }
            `
        });

        const plane = new PlaneBufferGeometry(width, height);
        const quad: any = new Mesh(plane, this.material);
        quad.position.z = -100;
        this.sceneRTT.add(quad);

        this.renderer = new WebGLRenderer({ alpha: true, preserveDrawingBuffer: true });
        this.renderer.setPixelRatio(window.devicePixelRatio || 1);
        this.renderer.setSize(width, height);
        this.renderer.autoClear = false;

        const app = document.createElement('div');
        app.id = 'dz-screenshot-helper';
        app.style.display = 'none';
        app.appendChild(this.renderer.domElement);
        document.body.appendChild(app);
    }

    resize() {
        if (!this.renderer) return;
        const old = document.getElementById('dz-screenshot-helper');
        if (old) old.remove();
        this.createRenderer();
    }

    animate() {
        requestAnimationFrame(this.animate);
        if (!this.renderer) return;
        this.renderer.clear();
        this.renderer.render(this.sceneRTT, this.cameraRTT, this.rtTexture, true);
        if (this.request) {
            const request = this.request;
            this.request = null;
            this.handleRequest(request);
        }
    }

    handleRequest(request: ScreenshotRequest) {
        const width = Math.max(1, window.innerWidth);
        const height = Math.max(1, window.innerHeight);
        const read = new Uint8Array(width * height * 4);
        this.renderer.readRenderTargetPixels(this.rtTexture, 0, 0, width, height, read);

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;
        ctx.putImageData(new ImageData(new Uint8ClampedArray(read.buffer), width, height), 0, 0);

        let type = 'image/png';
        if (request.encoding === 'jpg') type = 'image/jpeg';
        if (request.encoding === 'webp') type = 'image/webp';
        const quality = request.quality || 0.95;
        const imageURL = canvas.toDataURL(type, quality);

        const getFormData = () => {
            const formData = new FormData();
            formData.append(request.targetField, dataURItoBlob(imageURL), `screenshot.${request.encoding || 'png'}`);
            return formData;
        };

        fetch(request.targetURL, {
            method: 'POST',
            mode: 'cors',
            headers: request.headers || {},
            body: request.targetField ? getFormData() : JSON.stringify({ data: imageURL, id: request.correlation })
        })
        .then(response => response.text())
        .then(text => {
            if (request.resultURL) {
                fetch(request.resultURL, { method: 'POST', mode: 'cors', body: JSON.stringify({ data: text, id: request.correlation }) });
            }
        });
    }
}

const dzScreenshotUI = new DriftzoneScreenshotUI();
dzScreenshotUI.initialize();
