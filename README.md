Successively add HTML fragments to the DOM on demand

**How?**

- CableReady is used to insert a new set of items using `insert_adjacent_html` before a `#sentinel` element after a "Load more" button is clicked.
- A scoped page morph is used to determine the next `page` and hides the "Load more" button when the last page is reached.

**Caveat**

Note that in a real-world app, you'd probably want to use model partials and collection rendering instead of inline rendering the items.

**Variations**

- Use a [Stimulus](https://stimulus.hotwire.dev) controller and an `IntersectionObserver` to automatically trigger loading:

```js
import ApplicationController from "./application_controller";
import { useIntersection } from "stimulus-use";

export default class extends ApplicationController {
  static targets = ["button"];

  connect() {
    super.connect();
    useIntersection(this, { element: this.buttonTarget });
  }

  appear() {
    this.buttonTarget.disabled = true;
    this.buttonTarget.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';

    this.stimulate("ArticlesInfiniteScroll#load_more", this.buttonTarget);
  }
}
```

- This example uses [Pagy](https://ddnexus.github.io/pagy/) for pagination, but of course you could also just use `.limit` and `.offset` or any other pagination method.
